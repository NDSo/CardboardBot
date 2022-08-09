import 'dart:convert';

import 'package:cardboard_bot/extensions.dart';
import 'package:googleapis/firestore/v1.dart' as firestore;

import 'repository.dart';

class FirestoreRepository<A> extends Repository<A> {
  final A Function(Map<String, dynamic> map) _objectFromJson;
  final Codec<String, String> _compressionCodec;
  final firestore.FirestoreApi _firestoreApi;
  final String _googleProjectId;
  final String _collectionId;

  firestore.ProjectsDatabasesDocumentsResource get _documentsApi => _firestoreApi.projects.databases.documents;

  String get _databasePath => "projects/$_googleProjectId/databases/(default)";

  String get _documentsPath => "$_databasePath/documents";

  String get _collectionPath => "$_documentsPath/$_collectionId";

  String _fullPath(String path) => "$_collectionPath/$path";

  FirestoreRepository({
    required A Function(Map<String, dynamic> map) objectFromJson,
    required Codec<String, String> compressionCodec,
    required firestore.FirestoreApi firestoreApi,
    required String googleProjectId,
    required String collectionId,
  })  : _objectFromJson = objectFromJson,
        _compressionCodec = compressionCodec,
        _firestoreApi = firestoreApi,
        _googleProjectId = googleProjectId,
        _collectionId = collectionId;


  A _objectFromFields(Map<String, firestore.Value> fields) {
    return _objectFromJson(jsonDecode(_compressionCodec.decode(fields["object"]!.stringValue!)) as Map<String, dynamic>);
  }

  Map<String, firestore.Value> _objectToFields(A object) {
    return {"object": firestore.Value(stringValue: _compressionCodec.encode(jsonEncode(object)))};
  }

  @override
  Future<List<A>> getAll() async {
    List<firestore.Document> documents = (await _documentsApi.list(_documentsPath, _collectionId)).documents ?? [];

    return documents.map<A>((e) => _objectFromFields(e.fields!)).toList();
  }

  @override
  Future<A?> getById(String id) async {
    var document = await _documentsApi.get(_fullPath(id));
    return _objectFromFields(document.fields!);
  }

  @override
  Future<List<A>> getByIds(Set<String> ids) async {
    // [BatchGetDocumentsResponse] is implemented incorrectly, only returns a single document
    var documents = await ids.map(
      (id) async {
        return _documentsApi.get(
          _fullPath(id),
        );
      },
    ).waitAll();
    return documents.map((e) => _objectFromFields(e.fields!)).toList();
  }

  @override
  Future<void> upsert({required List<String> ids, required List<A> objects}) async {
    var entries = Map.fromIterables(ids, objects).entries;
    List<Future<firestore.Document>> list = entries.map(
      (entry) async {
        return _documentsApi.patch(
          firestore.Document(
            name: _fullPath(entry.key),
            fields: _objectToFields(entry.value),
          ),
          _fullPath(entry.key),
        );
      },
    ).toList();
    await Future.wait(list);
    return;
  }

  @override
  Future<void> delete(Set<String> ids) async {
    List<Future<firestore.Empty>> list = ids.map(
      (id) async {
        return _documentsApi.delete(
          _fullPath(id),
        );
      },
    ).toList();
    await Future.wait(list);
    return;
  }
}
