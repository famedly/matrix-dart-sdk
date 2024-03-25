extension FilterMap<K, V> on Map<K, V> {
  Map<K2, V2> filterMap<K2, V2>(MapEntry<K2, V2>? Function(K, V) f) =>
      Map.fromEntries(
          entries.map((e) => f(e.key, e.value)).whereType<MapEntry<K2, V2>>());

  Map<K2, V2> catchMap<K2, V2>(MapEntry<K2, V2> Function(K, V) f) =>
      filterMap((k, v) {
        try {
          return f(k, v);
        } catch (_) {
          return null;
        }
      });
}
