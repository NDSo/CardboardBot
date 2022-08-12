extension SmartMap<A, B> on Map<A, B> {
  B? get(A key) {
    return this[key];
  }

  List<B> getMany(Set<A> keys) {
    return [
      for (var key in keys) this[key],
    ].whereType<B>().toList();
  }
}
