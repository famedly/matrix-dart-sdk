import 'package:matrix/matrix.dart';

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
        if (isValidMemEvent(mem)) {
          final callMem =
              CallMembership.fromJson(mem, event.senderId, event.room.id);
          if (callMem != null) callMemberships.add(callMem);
        }
      }
    }
    return FamedlyCallMemberEvent(memberships: callMemberships);
  }
}

class CallMembership {
  final String userId;
  final String callId;
  final String? application;
  final String? scope;
  final CallBackend backend;
  final String deviceId;
  final int expiresTs;
  final String membershipId;
  final List? feeds;

  final String roomId;

  CallMembership({
    required this.userId,
    required this.callId,
    required this.backend,
    required this.deviceId,
    required this.expiresTs,
    required this.roomId,
    required this.membershipId,
    this.application = 'm.call',
    this.scope = 'm.room',
    this.feeds,
  });

  Map<String, dynamic> toJson() {
    return {
      'call_id': callId,
      'application': application,
      'scope': scope,
      'foci_active': [backend.toJson()],
      'device_id': deviceId,
      'expires_ts': expiresTs,
      'expires': 7200000, // element compatibiltiy remove asap
      'membershipID': membershipId, // sessionId
      if (feeds != null) 'feeds': feeds,
    };
  }

  static CallMembership? fromJson(Map json, String userId, String roomId) {
    try {
      return CallMembership(
        userId: userId,
        roomId: roomId,
        callId: json['call_id'],
        application: json['application'],
        scope: json['scope'],
        backend: (json['foci_active'] as List)
            .map((e) => CallBackend.fromJson(e))
            .first,
        deviceId: json['device_id'],
        expiresTs: json['expires_ts'],
        membershipId:
            json['membershipID'] ?? 'someone_forgot_to_set_the_membershipID',
        feeds: json['feeds'],
      );
    } catch (e, s) {
      Logs().e('[VOIP] call membership parsing failed. $json', e, s);
      return null;
    }
  }

  @override
  bool operator ==(other) =>
      identical(this, other) ||
      other is CallMembership &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          roomId == other.roomId &&
          callId == other.callId &&
          application == other.application &&
          scope == other.scope &&
          backend.type == other.backend.type &&
          deviceId == other.deviceId &&
          membershipId == other.membershipId;

  @override
  int get hashCode =>
      userId.hashCode ^
      roomId.hashCode ^
      callId.hashCode ^
      application.hashCode ^
      scope.hashCode ^
      backend.type.hashCode ^
      deviceId.hashCode ^
      membershipId.hashCode;

  // with a buffer of 1 minute just incase we were slow to process a
  // call event, if the device is actually dead it should
  // get removed pretty soon
  bool get isExpired =>
      expiresTs <
      DateTime.now()
          .subtract(CallTimeouts.expireTsBumpDuration)
          .millisecondsSinceEpoch;
}
