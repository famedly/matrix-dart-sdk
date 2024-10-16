import 'package:matrix/matrix.dart';

class CallParticipant {
  final VoIP voip;
  final String userId;
  final String? deviceId;

  CallParticipant(
    this.voip, {
    required this.userId,
    this.deviceId,
  });

  bool get isLocal =>
      userId == voip.client.userID && deviceId == voip.client.deviceID;

  String get id {
    String pid = userId;
    if (deviceId != null) {
      pid += ':$deviceId';
    }
    return pid;
  }

  @override
  String toString() {
    return id;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallParticipant &&
          userId == other.userId &&
          deviceId == other.deviceId;

  @override
  int get hashCode => Object.hash(userId.hashCode, deviceId.hashCode);
}
