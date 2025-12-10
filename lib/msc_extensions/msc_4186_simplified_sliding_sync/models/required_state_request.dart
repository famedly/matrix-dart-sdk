class RequiredStateRequest {
  /// The event type to match. If omitted then matches all types.
  final String? type;

  /// The event state key to match. If omitted then matches all state keys.
  ///
  /// Note: it is possible to match a specific state key, for all event types, by specifying [stateKey] but leaving [type] unset.
  final String? stateKey;

  const RequiredStateRequest({required this.type, required this.stateKey});

  Map<String, Object?> toJson() => {
        if (type != null) 'type': type,
        if (stateKey != null) 'state_key': stateKey,
      };
}
