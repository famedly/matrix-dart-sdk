import 'package:matrix/src/rtc/models/call_backend.dart';

class CallMembership {
  final String userId;
  final String callId;
  final String application;
  final String scope;
  final CallBackend backend;
  final String deviceId;
  final int expiresTs;

  CallMembership({
    required this.userId,
    required this.callId,
    required this.application,
    required this.scope,
    required this.backend,
    required this.deviceId,
    required this.expiresTs,
  });

  Map<String, dynamic> toJson() {
    return {
      'call_id': callId,
      'application': application,
      'scope': scope,
      'backend': backend.toJson(),
      'deviceId': deviceId,
      'expires_ts': expiresTs,
    };
  }

  factory CallMembership.fromJson(Map<String, dynamic> json, String userId) {
    return CallMembership(
      userId: userId,
      callId: json['call_id'],
      application: json['application'],
      scope: json['scope'],
      backend: CallBackend.fromJson(json['backend']),
      deviceId: json['device_id'],
      expiresTs: json['expires_ts'],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallMembership &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          callId == other.callId &&
          application == other.application &&
          scope == other.scope &&
          backend.type == other.backend.type &&
          deviceId == other.deviceId;

  @override
  int get hashCode =>
      userId.hashCode ^
      callId.hashCode ^
      application.hashCode ^
      scope.hashCode ^
      backend.type.hashCode ^
      deviceId.hashCode;

  // with a buffer of 10 seconds just incase we were slow to process a
  // call event, if the device is actually dead it should
  // get removed pretty soon
  bool get isExpired =>
      expiresTs >
      DateTime.now().add(Duration(seconds: 10)).millisecondsSinceEpoch;
}
