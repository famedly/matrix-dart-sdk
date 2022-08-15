import 'package:random_string/random_string.dart';
import 'package:webrtc_interface/webrtc_interface.dart';

void stopMediaStream(MediaStream? stream) async {
  stream?.getTracks().forEach((element) async {
    await element.stop();
  });
}

void setTracksEnabled(List<MediaStreamTrack> tracks, bool enabled) {
  tracks.forEach((element) {
    element.enabled = enabled;
  });
}

Future<bool> hasAudioDevice() async {
  //TODO(duan): implement this, check if there is any audio device
  return true;
}

Future<bool> hasVideoDevice() async {
  //TODO(duan): implement this, check if there is any video device
  return true;
}

String roomAliasFromRoomName(String roomName) {
  return roomName.trim().replaceAll('-', '').toLowerCase();
}

String genCallID() {
  return '${DateTime.now().millisecondsSinceEpoch}${randomAlphaNumeric(16)}';
}
