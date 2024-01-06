import 'dart:async';
import 'dart:typed_data';

import 'package:random_string/random_string.dart';
import 'package:webrtc_interface/webrtc_interface.dart';

import 'package:matrix/matrix.dart';

Future<void> stopMediaStream(MediaStream? stream) async {
  if (stream != null) {
    for (final track in stream.getTracks()) {
      try {
        await track.stop();
      } catch (e, s) {
        Logs().e('[VOIP] stopping track ${track.id} failed', e, s);
      }
    }
    try {
      await stream.dispose();
    } catch (e, s) {
      Logs().e('[VOIP] disposing stream ${stream.id} failed', e, s);
    }
  }
}

void setTracksEnabled(List<MediaStreamTrack> tracks, bool enabled) {
  for (final element in tracks) {
    element.enabled = enabled;
  }
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

bool listEquals<E>(List<E> list1, List<E> list2) {
  if (identical(list1, list2)) {
    return true;
  }

  if (list1.length != list2.length) {
    return false;
  }

  for (var i = 0; i < list1.length; i += 1) {
    if (list1[i] != list2[i]) {
      return false;
    }
  }

  return true;
}
