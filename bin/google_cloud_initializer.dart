import 'dart:io';

import 'package:googleapis_auth/auth_io.dart'
    show
        AutoRefreshingAuthClient,
        ServiceAccountCredentials,
        clientViaApplicationDefaultCredentials,
        clientViaServiceAccount;
import 'package:googleapis/storage/v1.dart' as storage;
import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:googleapis/secretmanager/v1.dart' as secret_manager;

class GoogleCloudInitializer {
  static GoogleCloudInitializer? _singleton;

  final String projectId;
  final storage.StorageApi storageApi;
  final firestore.FirestoreApi firestoreApi;
  final secret_manager.SecretManagerApi secretManagerApi;

  GoogleCloudInitializer._internal(
    this.projectId,
    this.storageApi,
    this.firestoreApi,
    this.secretManagerApi,
  );

  static Future<GoogleCloudInitializer> initialize({required String projectId}) async {
    if (_singleton != null) return _singleton!;

    List<String> scopes = [
      firestore.FirestoreApi.datastoreScope,
      secret_manager.SecretManagerApi.cloudPlatformScope,
      storage.StorageApi.devstorageReadWriteScope,
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
    );

    return _singleton!;
  }
}
