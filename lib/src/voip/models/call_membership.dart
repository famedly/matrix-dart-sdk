import 'package:matrix/matrix.dart';
import 'package:matrix/src/voip/models/call_backend.dart';

class FamedlyCallMemberEvent {
  final List<CallMembership> memberships;

  FamedlyCallMemberEvent({required this.memberships});

  Map<String, dynamic> toJson() {
    return {'memberships': memberships.map((e) => e.toJson()).toList()};
  }

  factory FamedlyCallMemberEvent.fromJson(Event event) {
    final List<CallMembership> callMemberships = [];
    final memberships = event.content.tryGetList('memberships');
    if (memberships != null && memberships.isNotEmpty) {
      for (final mem in memberships) {
        callMemberships
            .add(CallMembership.fromJson(mem, event.senderId, event.room.id));
      }
    }
    return FamedlyCallMemberEvent(memberships: callMemberships);
  }
}

class CallMembership {
  final String userId;
  final String callId;
  final String application;
  final String scope;
  final CallBackend backend;
  final String deviceId;
  final int expiresTs;

  final String roomId;

  CallMembership({
    required this.userId,
    required this.callId,
    required this.application,
    required this.scope,
    required this.backend,
    required this.deviceId,
    required this.expiresTs,
    required this.roomId,
  });

  Map<String, dynamic> toJson() {
    return {
      'call_id': callId,
      'application': application,
      'scope': scope,
      'backend': backend.toJson(),
      'device_id': deviceId,
      'expires_ts': expiresTs,
    };
  }

  factory CallMembership.fromJson(Map json, String userId, String roomId) {
    return CallMembership(
      userId: userId,
      roomId: roomId,
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
          roomId == other.roomId &&
          callId == other.callId &&
          application == other.application &&
          scope == other.scope &&
          backend.type == other.backend.type &&
          deviceId == other.deviceId;

  @override
  int get hashCode =>
      userId.hashCode ^
      roomId.hashCode ^
      callId.hashCode ^
      application.hashCode ^
      scope.hashCode ^
      backend.type.hashCode ^
      deviceId.hashCode;

  // with a buffer of 1 minute just incase we were slow to process a
  // call event, if the device is actually dead it should
  // get removed pretty soon
  bool get isExpired =>
      expiresTs <
      DateTime.now()
          .subtract(CallTimeouts.expireTsBumpDuration)
          .millisecondsSinceEpoch;
}
