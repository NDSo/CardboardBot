import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart'
    show AutoRefreshingAuthClient, ServiceAccountCredentials, clientViaApplicationDefaultCredentials, clientViaServiceAccount;
import 'package:googleapis/storage/v1.dart' as cs;
import 'package:googleapis/compute/v1.dart' as compute;
import 'package:googleapis/firestore/v1.dart' as firestore;

class GoogleCloudService {
  static GoogleCloudService? _singleton;
  final cs.StorageApi _storageApi;
  final compute.ComputeApi _computeApi;
  final firestore.FirestoreApi _firestoreApi;

  firestore.ProjectsDatabasesDocumentsResource get _documentsApi => _firestoreApi.projects.databases.documents;
  final String _projectId;

  String get _defaultBucket => "$_projectId.appspot.com";

  static String get _firestoreDatabasePath => "projects/cardboardbot-f4c69/databases/(default)";

  static String get _firestoreDocumentPath => "$_firestoreDatabasePath/documents";

  static String _firestorePath(String name) => "$_firestoreDocumentPath/$name";

  GoogleCloudService._internal(this._projectId, this._storageApi, this._computeApi, this._firestoreApi);

  factory GoogleCloudService() {
    if (_singleton == null) throw Exception("$GoogleCloudService needs initialized!");
    return _singleton!;
  }

  static Future<void> initialize({required String projectId, String? serviceAccountCredentials}) async {
    if (_singleton != null) return;

    List<String> scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/datastore",
      "https://www.googleapis.com/auth/devstorage.read_write",
      "https://www.googleapis.com/auth/compute",
    ];

    AutoRefreshingAuthClient? client;

    if (serviceAccountCredentials != null) {
      // LOCAL DEVELOPMENT
      var clientCredentials = ServiceAccountCredentials.fromJson(serviceAccountCredentials);
      client = await clientViaServiceAccount(clientCredentials, scopes);
    } else {
      // GOOGLE ENVIRONMENT
      client = await clientViaApplicationDefaultCredentials(scopes: scopes);
    }

    _singleton = GoogleCloudService._internal(
      projectId,
      cs.StorageApi(client),
      compute.ComputeApi(client),
      firestore.FirestoreApi(client),
    );
  }

  Future<compute.Metadata?> getComputeEngineMetadata() async {
    var project = await _computeApi.projects.get(_projectId);
    return project.commonInstanceMetadata;
  }

  // Firestore

  Future<T> get<T>({required T Function(dynamic a) fromJson, required String name, bool zip = false}) async {
    String string = (await _documentsApi.get(_firestorePath(name))).fields!["object"]!.stringValue!;

    dynamic json;
    if (zip) {
      json = jsonDecode(utf8.decode(gzip.decode(base64Decode(string))));
    } else {
      json = jsonDecode(string);
    }

    return fromJson(json);
  }

  Future<void> patch({required Object object, required String name, bool zip = false}) async {
    String data;
    if (zip) {
      data = base64Encode(gzip.encode(utf8.encode(jsonEncode(object))));
    } else {
      data = jsonEncode(object);
    }
    await _documentsApi.patch(
      firestore.Document(
        name: _firestorePath(name),
        fields: {"object": firestore.Value(stringValue: data)},
      ),
      _firestorePath(name),
    );
  }

  // CLOUD STORAGE
  Future<void> write({required Object object, required String name, bool zip = false}) async {
    List<int> data = [];
    if (zip) {
      data = gzip.encode(utf8.encode(jsonEncode(object)));
    } else {
      data = jsonEncode(object).codeUnits;
    }
    await _storageApi.objects.insert(
      cs.Object(name: name),
      _defaultBucket,
      uploadMedia: cs.Media(Stream.value(data), data.length),
    );
  }

  Future<T?> read<T>({required T Function(dynamic a) fromJson, required String name, bool zip = false}) async {
    try {
      cs.Media media = await _storageApi.objects
          .get(
            _defaultBucket,
            name,
            downloadOptions: cs.DownloadOptions.fullMedia,
          )
          .then<cs.Media>((value) => value as cs.Media);
      List<int> bytes = (await media.stream.toList()).expand<int>((element) => element).toList();
      dynamic json;
      if (zip) {
        json = jsonDecode(utf8.decode(gzip.decode(bytes)));
      } else {
        json = jsonDecode(String.fromCharCodes(bytes));
      }

      return fromJson(json);
    } on cs.DetailedApiRequestError catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<List<T>?> readList<T>({required T Function(dynamic a) fromJson, required String name, bool zip = false}) async {
    return await read(fromJson: (dynamic d) => (d as List).cast<Map<String, dynamic>>().map<T>(fromJson).toList(), name: name, zip: zip);
  }
}
