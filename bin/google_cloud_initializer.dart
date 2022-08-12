import 'dart:io';

import 'package:googleapis_auth/auth_io.dart'
    show AutoRefreshingAuthClient, ServiceAccountCredentials, clientViaApplicationDefaultCredentials, clientViaServiceAccount;
import 'package:googleapis/storage/v1.dart' as storage;
import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:googleapis/secretmanager/v1.dart' as secret_manager;
import 'package:kiwi/kiwi.dart';

class GoogleCloudInitializer {
  static GoogleCloudInitializer? _singleton;

  GoogleCloudInitializer._internal();

  static Future<void> initialize({required String projectId}) async {
    if (_singleton != null) return;

    List<String> scopes = [
      firestore.FirestoreApi.datastoreScope,
      secret_manager.SecretManagerApi.cloudPlatformScope,
      storage.StorageApi.devstorageReadWriteScope,
    ];

    AutoRefreshingAuthClient? client;

    var googleConfigFile = File("configs/googleapis_service_account.json");
    if (googleConfigFile.existsSync()) {
      // LOCAL DEVELOPMENT
      var clientCredentials = ServiceAccountCredentials.fromJson(googleConfigFile.readAsStringSync());
      client = await clientViaServiceAccount(clientCredentials, scopes);
    } else {
      // CLOUD ENVIRONMENT
      client = await clientViaApplicationDefaultCredentials(scopes: scopes);
    }

    var storageApi = storage.StorageApi(client);
    var firestoreApi = firestore.FirestoreApi(client);
    var secretManagerApi = secret_manager.SecretManagerApi(client);

    KiwiContainer().registerInstance(storageApi);
    KiwiContainer().registerInstance(firestoreApi);
    KiwiContainer().registerInstance(secretManagerApi);

    _singleton = GoogleCloudInitializer._internal();
  }
}
