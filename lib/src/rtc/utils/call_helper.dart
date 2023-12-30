import 'package:matrix/src/rtc/utils/types.dart';
import 'package:random_string/random_string.dart';
import 'package:webrtc_interface/webrtc_interface.dart';

import 'package:matrix/matrix.dart';

import 'package:sdp_transform/sdp_transform.dart' as sdp_transform;

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
  throw UnimplementedError();
}

Future<bool> hasVideoDevice() async {
  throw UnimplementedError();
}

String roomAliasFromRoomName(String roomName) {
  return roomName.trim().replaceAll('-', '').toLowerCase();
}

String genCallID() {
  return '${DateTime.now().millisecondsSinceEpoch}${randomAlphaNumeric(16)}';
}

CallType getCallType(String sdp) {
  try {
    final session = sdp_transform.parse(sdp);
    if (session['media'].indexWhere((e) => e['type'] == 'video') != -1) {
      return CallType.kVideo;
    }
  } catch (e, s) {
    Logs().e('Failed to getCallType', e, s);
  }

  return CallType.kVoice;
}
