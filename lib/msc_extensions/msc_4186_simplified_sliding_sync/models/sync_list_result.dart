class SyncListResult {
  /// The total number of entries in the list.
  final int count;

  const SyncListResult({required this.count});

  factory SyncListResult.fromJson(Map<String, Object?> json) =>
      SyncListResult(count: json['count'] as int);
}
