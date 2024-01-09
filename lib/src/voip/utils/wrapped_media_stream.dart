import 'package:webrtc_interface/webrtc_interface.dart';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:matrix/src/voip/utils/stream_helper.dart';

/// Wrapped MediaStream, used to adapt Widget to display
class WrappedMediaStream {
  MediaStream? stream;
  final Participant participant;
  final Room room;

  /// Current stream type, usermedia or screen-sharing
  String purpose;
  bool audioMuted;
  bool videoMuted;
  final Client client;
  VideoRenderer renderer;
  final bool isWeb;
  final bool isGroupCall;
  final RTCPeerConnection? pc;

  /// for debug
  String get title => '$displayName:$purpose:a[$audioMuted]:v[$videoMuted]';
  bool stopped = false;

  final CachedStreamController<WrappedMediaStream> onMuteStateChanged =
      CachedStreamController();

  void Function(MediaStream stream)? onNewStream;

  WrappedMediaStream(
      {this.stream,
      this.pc,
      required this.renderer,
      required this.room,
      required this.participant,
      required this.purpose,
      required this.client,
      required this.audioMuted,
      required this.videoMuted,
      required this.isWeb,
      required this.isGroupCall});

  /// Initialize the video renderer
  Future<void> initialize() async {
    await renderer.initialize();
    renderer.srcObject = stream;
    renderer.onResize = () {
      Logs().i(
          'onResize [${stream!.id.substring(0, 8)}] ${renderer.videoWidth} x ${renderer.videoHeight}');
    };
  }

  Participant get localParticipant =>
      Participant(userId: client.userID!, deviceId: client.deviceID!);

  Future<void> dispose() async {
    renderer.srcObject = null;

    /// libwebrtc does not provide a way to clone MediaStreams. So stopping the
    /// local stream here would break calls with all other participants if anyone
    /// leaves. The local stream is manually disposed when user leaves. On web
    /// streams are actually cloned.
    if (!isGroupCall || isWeb) {
      await stopMediaStream(stream);
    }

    stream = null;
    await renderer.dispose();
  }

  Future<void> disposeRenderer() async {
    renderer.srcObject = null;
    await renderer.dispose();
  }

  Uri? get avatarUrl => getUser().avatarUrl;

  String get avatarName =>
      getUser().calcDisplayname(mxidLocalPartFallback: false);

  String? get displayName => getUser().displayName;

  User getUser() {
    return room.unsafeGetUserFromMemoryOrFallback(participant.userId);
  }

  bool isLocal() {
    return participant == localParticipant;
  }

  bool isAudioMuted() {
    return (stream != null && stream!.getAudioTracks().isEmpty) || audioMuted;
  }

  bool isVideoMuted() {
    return (stream != null && stream!.getVideoTracks().isEmpty) || videoMuted;
  }

  void setNewStream(MediaStream newStream) {
    stream = newStream;
    renderer.srcObject = stream;
    if (onNewStream != null) {
      onNewStream?.call(stream!);
    }
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
