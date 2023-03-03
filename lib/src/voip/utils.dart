import 'dart:async';

import 'package:random_string/random_string.dart';
import 'package:webrtc_interface/webrtc_interface.dart';

import 'package:matrix/matrix.dart';

Future<void> stopMediaStream(MediaStream? stream) async {
  if (stream != null) {
    for (final track in stream.getTracks()) {
      try {
        await track.stop();
      } catch (e) {
        Logs().e('[VOIP] stopping track ${track.id} failed', e);
      }
    }
    try {
      await stream.dispose();
    } catch (e) {
      Logs().e('[VOIP] disposing stream ${stream.id} failed', e);
    }
  }
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
