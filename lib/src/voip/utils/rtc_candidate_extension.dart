import 'package:webrtc_interface/webrtc_interface.dart';

extension RTCIceCandidateExt on RTCIceCandidate {
  bool get isValid =>
      sdpMLineIndex != null &&
      sdpMid != null &&
      candidate != null &&
      candidate!.isNotEmpty;
}
