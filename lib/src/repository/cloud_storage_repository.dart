import 'dart:convert';

import 'package:cardboard_bot/extensions.dart';
import 'package:googleapis/storage/v1.dart' as cloud_storage;

import 'repository.dart';

class CloudStorageRepository<A> extends Repository<A> {
  final A Function(Map<String, dynamic> map) _objectFromJson;
  final Codec<Object?, List<int>> _codec;
  final cloud_storage.StorageApi _storageApi;
  final String _googleProjectId;
  final String _documentName;

  String get _defaultBucket => "$_googleProjectId.appspot.com";

  CloudStorageRepository({
    required A Function(Map<String, dynamic> map) objectFromJson,
    required Codec<String, List<int>> compressionCodec,
    required cloud_storage.StorageApi storageApi,
    required String googleProjectId,
    required String documentName,
  })  : _objectFromJson = objectFromJson,
        _codec = JsonCodec().fuse(compressionCodec),
        _storageApi = storageApi,
        _googleProjectId = googleProjectId,
        _documentName = documentName;

  Future<Map<String, A>> _getAll() async {
    try {
      cloud_storage.Media media = await _storageApi.objects
          .get(
            _defaultBucket,
            _documentName,
            downloadOptions: cloud_storage.DownloadOptions.fullMedia,
          )
          .then<cloud_storage.Media>((value) => value as cloud_storage.Media);
      List<int> bytes = (await media.stream.toList()).expand<int>((element) => element).toList();
      var json = _codec.decode(bytes);
      return (json as Map<String, dynamic>).map<String, A>((key, value) => MapEntry(key, _objectFromJson(value as Map<String, dynamic>)));
    } on cloud_storage.DetailedApiRequestError catch (e) {
      if (e.status == 404) return <String, A>{};
      rethrow;
    }
  }

  @override
  Future<List<A>> getAll() async {
    return (await _getAll()).values.toList();
  }

  @override
  Future<A?> getById(String id) async {
    var map = await _getAll();
    return map[id];
  }

  @override
  Future<List<A>> getByIds(Set<String> ids) async {
    var map = await _getAll();
    return map.getMany(ids);
  }

  @override
  Future<void> upsert({required List<String> ids, required List<A> objects}) async {
    var newMap = Map.fromIterables(ids, objects);
    var existingMap = await _getAll();
    existingMap.addAll(newMap);
    List<int> data = _codec.encode(existingMap);
    await _storageApi.objects.insert(
      cloud_storage.Object(name: _documentName),
      _defaultBucket,
      uploadMedia: cloud_storage.Media(Stream.value(data), data.length),
    );
    return;
  }

  @override
  Future<void> delete(Set<String> ids) async {
    var existingMap = await _getAll();
    existingMap.removeWhere((key, value) => ids.contains(key));
    List<int> data = _codec.encode(existingMap);
    await _storageApi.objects.insert(
      cloud_storage.Object(name: _documentName),
      _defaultBucket,
      uploadMedia: cloud_storage.Media(Stream.value(data), data.length),
    );
    return;
  }
}
