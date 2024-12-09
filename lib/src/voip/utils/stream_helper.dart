import 'package:collection/collection.dart';
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

Future<bool> hasMediaDevice(
  WebRTCDelegate delegate,
  MediaInputKind mediaInputKind,
) async {
  final devices = await delegate.mediaDevices.enumerateDevices();
  return devices
      .where((device) => device.kind == mediaInputKind.name)
      .isNotEmpty;
}

Future<void> updateMediaDevice(
  WebRTCDelegate delegate,
  MediaKind kind,
  List<RTCRtpSender> userRtpSenders, [
  MediaStreamTrack? track,
]) async {
  final sender = userRtpSenders
      .firstWhereOrNull((element) => element.track!.kind == kind.name);
  await sender?.track?.stop();
  if (track != null) {
    await sender?.replaceTrack(track);
  } else {
    final stream = await delegate.mediaDevices.getUserMedia({kind.name: true});
    MediaStreamTrack? track;
    if (kind == MediaKind.audio) {
      track = stream.getAudioTracks().firstOrNull;
    } else if (kind == MediaKind.video) {
      track = stream.getVideoTracks().firstOrNull;
    }
    if (track != null) {
      await sender?.replaceTrack(track);
    }
  }
}

String genCallID() {
  return '${DateTime.now().millisecondsSinceEpoch}${randomAlphaNumeric(16)}';
}
