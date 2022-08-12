import 'dart:convert';
import 'dart:io';

import 'package:cardboard_bot/extensions.dart';

import 'repository.dart';

class LocalFileRepository<A> extends Repository<A> {
  final A Function(Map<String, dynamic> map) _objectFromJson;
  final Codec<Object?, List<int>> _codec;
  final String _filePath;

  LocalFileRepository({
    required A Function(Map<String, dynamic> map) objectFromJson,
    required Codec<String, List<int>> compressionCodec,
    required String filePath,
  })  : _objectFromJson = objectFromJson,
        _codec = JsonCodec().fuse(compressionCodec),
        _filePath = filePath;

  Future<Map<String, A>> _getAll() async {
    var file = File(_filePath);
    if (file.existsSync()) {
      var json = _codec.decode(file.readAsBytesSync());
      return (json as Map<String, dynamic>).map<String, A>((key, value) => MapEntry(key, _objectFromJson(value as Map<String, dynamic>)));
    } else {
      return <String, A>{};
    }
  }

  @override
  Future<List<A>> getAll() async {
    return (await _getAll()).values.toList();
  }

  @override
  Future<A?> getById(String id) async {
    var all = await _getAll();
    return all[id];
  }

  @override
  Future<List<A>> getByIds(Set<String> ids) async {
    var all = await _getAll();
    return all.getMany(ids);
  }

  @override
  Future<void> upsert({required List<String> ids, required List<A> objects}) async {
    var newMap = Map.fromIterables(ids, objects);
    var existingObjects = await _getAll();
    existingObjects.addAll(newMap);
    var file = File(_filePath)..createSync(recursive: true);
    file.writeAsBytesSync(_codec.encode(existingObjects));
    return;
  }

  @override
  Future<void> delete(Set<String> ids) async {
    var existingObjects = await _getAll();
    existingObjects.removeWhere((key, value) => ids.contains(key));
    var file = File(_filePath)..createSync(recursive: true);
    file.writeAsBytesSync(_codec.encode(existingObjects));
    return;
  }
}
