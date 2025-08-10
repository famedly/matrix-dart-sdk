import 'package:webrtc_interface/webrtc_interface.dart';

import 'package:matrix/matrix.dart';

/// Delegate WebRTC basic functionality.
abstract class WebRTCDelegate {
  MediaDevices get mediaDevices;
  Future<RTCPeerConnection> createPeerConnection(
    Map<String, dynamic> configuration, [
    Map<String, dynamic> constraints = const {},
  ]);
  Future<void> playRingtone();
  Future<void> stopRingtone();
  Future<void> registerListeners(CallSession session);
  Future<void> handleNewCall(CallSession session);
  Future<void> handleCallEnded(CallSession session);
  Future<void> handleMissedCall(CallSession session);
  Future<void> handleNewGroupCall(GroupCallSession groupCall);
  Future<void> handleGroupCallEnded(GroupCallSession groupCall);
  bool get isWeb;

  /// This should be set to false if any calls in the client are in kConnected
  /// state. If another room tries to call you during a connected call this fires
  /// a handleMissedCall
  bool get canHandleNewCall;
  EncryptionKeyProvider? get keyProvider;
}
