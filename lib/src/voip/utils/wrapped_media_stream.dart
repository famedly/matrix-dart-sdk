import 'package:webrtc_interface/webrtc_interface.dart';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:matrix/src/voip/utils/stream_helper.dart';

/// Wrapped MediaStream, used to adapt Widget to display
class WrappedMediaStream {
  MediaStream? stream;
  final CallParticipant participant;
  final Room room;
  final VoIP voip;

  /// Current stream type, usermedia or screen-sharing
  String purpose;
  bool audioMuted;
  bool videoMuted;
  final Client client;
  final bool isGroupCall;
  final RTCPeerConnection? pc;

  /// for debug
  String get title =>
      '${client.userID!}:${client.deviceID!} $displayName:$purpose:a[$audioMuted]:v[$videoMuted]';
  bool stopped = false;

  final CachedStreamController<WrappedMediaStream> onMuteStateChanged =
      CachedStreamController();

  final CachedStreamController<MediaStream> onStreamChanged =
      CachedStreamController();

  WrappedMediaStream({
    this.stream,
    this.pc,
    required this.room,
    required this.participant,
    required this.purpose,
    required this.client,
    required this.audioMuted,
    required this.videoMuted,
    required this.isGroupCall,
    required this.voip,
  });

  String get id => '${stream?.id}: $title';

  Future<void> dispose() async {
    // AOT it
    const isWeb = bool.fromEnvironment('dart.library.js_util');

    // libwebrtc does not provide a way to clone MediaStreams. So stopping the
    // local stream here would break calls with all other participants if anyone
    // leaves. The local stream is manually disposed when user leaves. On web
    // streams are actually cloned.
    if (!isGroupCall || isWeb) {
      await stopMediaStream(stream);
    }

    stream = null;
  }

  Uri? get avatarUrl => getUser().avatarUrl;

  String get avatarName =>
      getUser().calcDisplayname(mxidLocalPartFallback: false);

  String? get displayName => getUser().displayName;

  User getUser() {
    return room.unsafeGetUserFromMemoryOrFallback(participant.userId);
  }

  bool isLocal() {
    return participant == voip.localParticipant;
  }

  bool isAudioMuted() {
    return (stream != null && stream!.getAudioTracks().isEmpty) || audioMuted;
  }

  bool isVideoMuted() {
    return (stream != null && stream!.getVideoTracks().isEmpty) || videoMuted;
  }

  void setNewStream(MediaStream newStream) {
    stream = newStream;
    onStreamChanged.add(stream!);
  }

  void setAudioMuted(bool muted) {
    audioMuted = muted;
    onMuteStateChanged.add(this);
  }

  void setVideoMuted(bool muted) {
    videoMuted = muted;
    onMuteStateChanged.add(this);
  }
}
