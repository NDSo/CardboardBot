import 'dart:io';

import 'package:googleapis_auth/auth_io.dart'
    show AutoRefreshingAuthClient, ServiceAccountCredentials, clientViaApplicationDefaultCredentials, clientViaServiceAccount;
import 'package:googleapis/storage/v1.dart' as storage;
import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:googleapis/secretmanager/v1.dart' as secret_manager;
import 'package:googleapis/logging/v2.dart' as logging;
import 'package:logging/logging.dart';

class GoogleCloudInitializer {
  static GoogleCloudInitializer? _singleton;

  final String projectId;
  final storage.StorageApi storageApi;
  final firestore.FirestoreApi firestoreApi;
  final secret_manager.SecretManagerApi secretManagerApi;
  final logging.LoggingApi loggingApi;

  GoogleCloudInitializer._internal(this.projectId, this.storageApi, this.firestoreApi, this.secretManagerApi, this.loggingApi) {
    _setupCloudLogging();
  }

  static Future<GoogleCloudInitializer> initialize({required String projectId}) async {
    if (_singleton != null) return _singleton!;

    List<String> scopes = [
      firestore.FirestoreApi.datastoreScope,
      secret_manager.SecretManagerApi.cloudPlatformScope,
      storage.StorageApi.devstorageReadWriteScope,
      logging.LoggingApi.loggingWriteScope,
    ];

    AutoRefreshingAuthClient? client;

    var googleConfigFile = File("/cardboard_bot/configs/googleapis_service_account.json");
    if (googleConfigFile.existsSync()) {
      // LOCAL DEVELOPMENT
      var clientCredentials = ServiceAccountCredentials.fromJson(googleConfigFile.readAsStringSync());
      client = await clientViaServiceAccount(clientCredentials, scopes);
    } else {
      // CLOUD ENVIRONMENT
      client = await clientViaApplicationDefaultCredentials(scopes: scopes);
    }

    _singleton = GoogleCloudInitializer._internal(
      projectId,
      storage.StorageApi(client),
      firestore.FirestoreApi(client),
      secret_manager.SecretManagerApi(client),
      logging.LoggingApi(client),
    );

    return _singleton!;
  }

  void _setupCloudLogging() {
    // Attach Cloud Logging
    Logger.root.onRecord.listen(
      (LogRecord rec) async {
        if (rec.level <= Level.FINE) return;
        await loggingApi.entries.write(logging.WriteLogEntriesRequest(
          logName: "projects/$projectId/logs/cardboardBot",
          resource: logging.MonitoredResource(
            type: "global",
            labels: {
              "project_id": projectId,
            },
          ),
          labels: {
            "application": "cardboardBot",
          },
          entries: [
            logging.LogEntry(
              severity: rec.level.toCloudLogSeverity(),
              jsonPayload: {
                "message": "[${rec.time}] [${rec.level.name}] [${rec.loggerName}] ${rec.message}",
                if (rec.error != null && (rec.error is Error || rec.error is Exception)) "error": "${rec.error.toString()}",
                if (rec.stackTrace != null && (rec.level == Level.SEVERE || rec.level == Level.SHOUT)) "stackTrace": "${rec.stackTrace?.toString()}",
              },
              timestamp: DateTime.now().toUtc().toIso8601String(),
            )
          ],
        ));
      },
      onError: (Object e, StackTrace stackTrace) {
        print("FAILED TO LOG TO CLOUD!");
        print("error: ${e.toString()}");
        print("stacktrace: ${stackTrace.toString()}");
      },
    );
  }
}

extension _LogLevelExtension on Level {
  String toCloudLogSeverity() {
    if (this == Level.FINEST || this == Level.FINER || this == Level.FINE) return "DEBUG";
    if (this == Level.CONFIG) return "NOTICE";
    if (this == Level.INFO) return "INFO";
    if (this == Level.WARNING) return "WARNING";
    if (this == Level.SEVERE) return "ERROR";
    if (this == Level.SHOUT) return "ALERT";
    return "DEFAULT";
  }
}
