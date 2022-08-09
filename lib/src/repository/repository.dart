abstract class Repository<A > {
  Future<void> upsert({required List<String> ids, required List<A> objects});

  Future<void> delete(Set<String> ids);

  Future<List<A>> getAll();

  Future<List<A>> getByIds(Set<String> ids);
  Future<A?> getById(String id);
}
