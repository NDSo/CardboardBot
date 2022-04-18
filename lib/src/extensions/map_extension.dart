extension SmartMap<A, B> on Map<A, B> {
  B? get(A key) {
    return this[key];
  }
}
