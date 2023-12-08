/// The database always gives back an `_InternalLinkedHasMap<dynamic, dynamic>`.
/// This creates a deep copy of the json and makes sure that the format is
/// always `Map<String, Object?>`.
extension CopyMapExtension on Map {
  Map<String, Object?> get copy {
    final copy = Map<String, dynamic>.from(this);
    for (final entry in copy.entries) {
      copy[entry.key] = _castValue(entry.value);
    }
    return copy;
  }

  dynamic _castValue(dynamic value) {
    if (value is Map) {
      return value.copy;
    }
    if (value is List) {
      return value.map(_castValue).toList();
    }
    return value;
  }
}
