import 'package:cardboard_bot/extensions.dart';

import 'repository.dart';

class LocalMemoryRepository<A> extends Repository<A> {
  final Map<String, A> _localCache = {};

  LocalMemoryRepository();

  @override
  Future<List<A>> getAll() async {
    return _localCache.values.toList();
  }

  @override
  Future<List<A>> getByIds(Set<String> ids) async {
    return _localCache.getMany(ids);
  }

  @override
  Future<void> upsert({required List<String> ids, required List<A> objects}) async {
    var newMap = Map.fromIterables(ids, objects);
    _localCache.addAll(newMap);
    return;
  }

  @override
  Future<void> delete(Set<String> ids) async {
    for (var id in ids) {
      _localCache.remove(id);
    }
    return;
  }

  @override
  Future<A?> getById(String id) async {
    return _localCache[id];
  }
}
