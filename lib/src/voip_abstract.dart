import 'dart:io';

class MediaStreamTrack {
  bool get enabled => false;
  set enabled(bool value) {}
  String get kind => throw UnimplementedError();
  Future<void> stop() async {}
  Future<void> enableSpeakerphone(bool enable) async {}
}

class MediaStream {
  String get id => throw UnimplementedError();
  List<MediaStreamTrack> getAudioTracks() => throw UnimplementedError();
  List<MediaStreamTrack> getVideoTracks() => throw UnimplementedError();
  List<MediaStreamTrack> getTracks() => throw UnimplementedError();
  Future<void> dispose() async {}
}

class RTCPeerConnection {
  Function(RTCTrackEvent event)? onTrack;
  Function()? onRenegotiationNeeded;
  Function(RTCIceCandidate)? onIceCandidate;
  Function(dynamic state)? onIceGatheringState;
  Function(dynamic state)? onIceConnectionState;

  Future<RTCSessionDescription> createOffer(Map<String, dynamic> constraints) {
    throw UnimplementedError();
  }

  Future<RTCSessionDescription> createAnswer(Map<String, dynamic> constraints) {
    throw UnimplementedError();
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {}
  Future<void> setLocalDescription(RTCSessionDescription description) async {}

  Future<RTCRtpSender> addTrack(
      MediaStreamTrack track, MediaStream stream) async {
    return RTCRtpSender();
  }

  Future<void> removeTrack(RTCRtpSender sender) async {}

  Future<void> close() async {}

  Future<void> dispose() async {}

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {}

  Future<void> addStream(MediaStream stream) async {}

  Future<void> removeStream(MediaStream stream) async {}

  Future<List<dynamic>> getTransceivers() async {
    throw UnimplementedError();
  }

  Future<List<RTCRtpSender>> getSenders() async {
    throw UnimplementedError();
  }

  Future<void> addCandidate(RTCIceCandidate candidate) async {}

  dynamic get signalingState => throw UnimplementedError();
}

class RTCIceCandidate {
  String get candidate => throw UnimplementedError();
  String get sdpMid => throw UnimplementedError();
  int get sdpMLineIndex => throw UnimplementedError();
  Map<String, dynamic> toMap() => throw UnimplementedError();
  RTCIceCandidate(String candidate, String sdpMid, int sdpMLineIndex);
}

class RTCRtpSender {
  MediaStreamTrack? get track => throw UnimplementedError();
  DtmfSender get dtmfSender => throw UnimplementedError();
}

class RTCSessionDescription {
  late String type;
  late String sdp;
  RTCSessionDescription(this.sdp, this.type);
}

class RTCTrackEvent {
  late List<MediaStream> streams;
}

enum TransceiverDirection {
  SendRecv,
  SendOnly,
  RecvOnly,
  Inactive,
}

enum RTCSignalingState { RTCSignalingStateStable }

class RTCVideoRenderer {}

const kIsWeb = false;

bool get kIsMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

class Helper {
  static Future<void> switchCamera(MediaStreamTrack track) async {}
}

class DtmfSender {
  Future<void> insertDTMF(String tones) async {}
}

Future<MediaStream> createPeerConnection(
    Map<String, dynamic> constraints) async {
  throw UnimplementedError();
}
