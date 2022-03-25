import 'package:matrix/src/voip.dart';
import 'package:webrtc_interface/src/rtc_video_renderer.dart';
import 'package:webrtc_interface/src/rtc_peerconnection.dart';
import 'package:webrtc_interface/src/mediadevices.dart';

class FakeVoIPDelegate extends WebRTCDelegate {
  @override
  Future<RTCPeerConnection> createPeerConnection(
      Map<String, dynamic> configuration,
      [Map<String, dynamic> constraints = const {}]) {
    // TODO: implement createPeerConnection
    throw UnimplementedError();
  }

  @override
  VideoRenderer createRenderer() {
    // TODO: implement createRenderer
    throw UnimplementedError();
  }

  @override
  void handleCallEnded(CallSession session) {
    // TODO: implement handleCallEnded
  }

  @override
  void handleNewCall(CallSession session) {
    // TODO: implement handleNewCall
  }

  @override
  // TODO: implement isBackgroud
  bool get isBackgroud => throw UnimplementedError();

  @override
  // TODO: implement isWeb
  bool get isWeb => throw UnimplementedError();

  @override
  // TODO: implement mediaDevices
  MediaDevices get mediaDevices => throw UnimplementedError();

  @override
  void playRingtone() {
    // TODO: implement playRingtone
  }

  @override
  void stopRingtone() {
    // TODO: implement stopRingtone
  }
}
