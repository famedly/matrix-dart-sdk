import 'dart:async';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/voip/models/call_membership.dart';

abstract class CallBackend {
  String type;

  CallBackend({
    required this.type,
  });

  factory CallBackend.fromJson(Map<String, Object?> json) {
    final String type = json['type'] as String;
    if (type == 'mesh') {
      return MeshBackend(
        type: type,
      );
    } else if (type == 'livekit') {
      return LiveKitBackend(
        livekitAlias: json['livekit_alias'] as String,
        livekitServiceUrl: json['livekit_service_url'] as String,
        type: type,
      );
    } else {
      throw MatrixSDKVoipException(
          'Invalid type: $type in CallBackend.fromJson');
    }
  }

  Map<String, Object?> toJson();

  bool get e2eeEnabled;

  CallParticipant? get activeSpeaker;

  WrappedMediaStream? get localUserMediaStream;

  WrappedMediaStream? get localScreenshareStream;

  List<WrappedMediaStream> get userMediaStreams;

  List<WrappedMediaStream> get screenShareStreams;

  bool get isLocalVideoMuted;

  bool get isMicrophoneMuted;

  Future<WrappedMediaStream?> initLocalStream(
    GroupCallSession groupCall, {
    WrappedMediaStream? stream,
  });

  Future<void> updateMediaDeviceForCalls();

  Future<void> setupP2PCallsWithExistingMembers(GroupCallSession groupCall);

  Future<void> setupP2PCallWithNewMember(
    GroupCallSession groupCall,
    CallParticipant rp,
    CallMembership mem,
  );

  Future<void> dispose(GroupCallSession groupCall);

  Future<void> onNewParticipant(
    GroupCallSession groupCall,
    List<CallParticipant> anyJoined,
  );

  Future<void> onLeftParticipant(
    GroupCallSession groupCall,
    List<CallParticipant> anyLeft,
  );

  Future<void> requestEncrytionKey(
    GroupCallSession groupCall,
    List<CallParticipant> remoteParticipants,
  );

  Future<void> onCallEncryption(
    GroupCallSession groupCall,
    String userId,
    String deviceId,
    Map<String, dynamic> content,
  );

  Future<void> onCallEncryptionKeyRequest(
    GroupCallSession groupCall,
    String userId,
    String deviceId,
    Map<String, dynamic> content,
  );

  Future<void> setDeviceMuted(
    GroupCallSession groupCall,
    bool muted,
    MediaInputKind kind,
  );

  Future<void> setScreensharingEnabled(
    GroupCallSession groupCall,
    bool enabled,
    String desktopCapturerSourceId,
  );

  List<Map<String, String>>? getCurrentFeeds();

  @override
  bool operator ==(Object other);
  @override
  int get hashCode;
}
