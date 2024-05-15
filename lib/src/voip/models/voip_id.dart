class VoipId {
  final String roomId;
  final String callId;
  final String? callBackendType;
  final String? application;
  final String? scope;

  VoipId({
    required this.roomId,
    required this.callId,
    this.callBackendType,
    this.application,
    this.scope,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoipId &&
          roomId == other.roomId &&
          callId == other.callId &&
          callBackendType == other.callBackendType &&
          application == other.application &&
          scope == other.scope;

  @override
  int get hashCode =>
      roomId.hashCode ^
      callId.hashCode ^
      callBackendType.hashCode ^
      application.hashCode ^
      scope.hashCode;
}
