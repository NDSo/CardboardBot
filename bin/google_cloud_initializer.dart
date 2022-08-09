import 'dart:io';

import 'package:googleapis_auth/auth_io.dart'
    show AutoRefreshingAuthClient, ServiceAccountCredentials, clientViaApplicationDefaultCredentials, clientViaServiceAccount;
import 'package:googleapis/storage/v1.dart' as storage;
import 'package:googleapis/compute/v1.dart' as compute;
import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:kiwi/kiwi.dart';

class GoogleCloudInitializer {
  static GoogleCloudInitializer? _singleton;

  GoogleCloudInitializer._internal();

  static Future<void> initialize({required String projectId}) async {
    if (_singleton != null) return;

    List<String> scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/datastore",
      "https://www.googleapis.com/auth/devstorage.read_write",
      "https://www.googleapis.com/auth/compute",
    ];

    AutoRefreshingAuthClient? client;

    var googleConfigFile = File("cardboard_bot/configs/googleapis_service_account.json");
    if (googleConfigFile.existsSync()) {
      // LOCAL DEVELOPMENT
      var clientCredentials = ServiceAccountCredentials.fromJson(googleConfigFile.readAsStringSync());
      client = await clientViaServiceAccount(clientCredentials, scopes);
    } else {
      // CLOUD ENVIRONMENT
      client = await clientViaApplicationDefaultCredentials(scopes: scopes);
    }

    var storageApi = storage.StorageApi(client);
    var computeApi = compute.ComputeApi(client);
    var firestoreApi = firestore.FirestoreApi(client);

    KiwiContainer().registerInstance(storageApi);
    KiwiContainer().registerInstance(computeApi);
    KiwiContainer().registerInstance(firestoreApi);

    _singleton = GoogleCloudInitializer._internal();
  }
}
