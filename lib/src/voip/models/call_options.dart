import 'package:matrix/matrix.dart';

/// Initialization parameters of the call session.
class CallOptions {
  final String callId;
  final CallType type;
  final CallDirection dir;

  /// client.deviceID
  final String localPartyId;
  final VoIP voip;
  final Room room;
  final List<Map<String, dynamic>> iceServers;
  final String? groupCallId;

  CallOptions({
    required this.callId,
    required this.type,
    required this.dir,
    required this.localPartyId,
    required this.voip,
    required this.room,
    required this.iceServers,
    this.groupCallId,
  });
}
