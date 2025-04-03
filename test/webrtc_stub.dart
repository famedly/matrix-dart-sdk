import 'dart:typed_data';

import 'package:webrtc_interface/webrtc_interface.dart';

import 'package:matrix/matrix.dart';

class MockWebRTCDelegate implements WebRTCDelegate {
  @override
  bool get canHandleNewCall => true;

  @override
  Future<RTCPeerConnection> createPeerConnection(
    Map<String, dynamic> configuration, [
    Map<String, dynamic> constraints = const {},
  ]) async =>
      MockRTCPeerConnection();

  @override
  Future<void> registerListeners(CallSession session) async {
    Logs().i('registerListeners called in MockWebRTCDelegate');
  }

  @override
  Future<void> handleCallEnded(CallSession session) async {
    Logs().i('handleCallEnded called in MockWebRTCDelegate');
  }

  @override
  Future<void> handleGroupCallEnded(GroupCallSession groupCall) async {
    Logs().i('handleGroupCallEnded called in MockWebRTCDelegate');
  }

  @override
  Future<void> handleMissedCall(CallSession session) async {
    Logs().i('handleMissedCall called in MockWebRTCDelegate');
  }

  @override
  Future<void> handleNewCall(CallSession session) async {
    Logs().i('handleNewCall called in MockWebRTCDelegate');
  }

  @override
  Future<void> handleNewGroupCall(GroupCallSession groupCall) async {
    Logs().i('handleNewGroupCall called in MockWebRTCDelegate');
  }

  @override
  bool get isWeb => false;

  @override
  MediaDevices get mediaDevices => MockMediaDevices();

  @override
  Future<void> playRingtone() async {
    Logs().i('playRingtone called in MockWebRTCDelegate');
  }

  @override
  Future<void> stopRingtone() async {
    Logs().i('stopRingtone called in MockWebRTCDelegate');
  }

  @override
  EncryptionKeyProvider? get keyProvider => MockEncryptionKeyProvider();
}

class MockEncryptionKeyProvider implements EncryptionKeyProvider {
  @override
  Future<void> onSetEncryptionKey(
    CallParticipant participant,
    Uint8List key,
    int index,
  ) async {
    Logs().i('Mock onSetEncryptionKey called for ${participant.id} ');
  }

  @override
  Future<Uint8List> onExportKey(CallParticipant participant, int index) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> onRatchetKey(CallParticipant participant, int index) {
    throw UnimplementedError();
  }
}

class MockMediaDevices implements MediaDevices {
  @override
  Function(dynamic event)? ondevicechange;

  @override
  Future<List<MediaDeviceInfo>> enumerateDevices() {
    throw UnimplementedError();
  }

  @override
  Future<MediaStream> getDisplayMedia(Map<String, dynamic> mediaConstraints) {
    throw UnimplementedError();
  }

  @override
  Future<List> getSources() {
    throw UnimplementedError();
  }

  @override
  MediaTrackSupportedConstraints getSupportedConstraints() {
    throw UnimplementedError();
  }

  @override
  Future<MediaStream> getUserMedia(
    Map<String, dynamic> mediaConstraints,
  ) async {
    return MockMediaStream('', '');
  }

  @override
  Future<MediaDeviceInfo> selectAudioOutput([AudioOutputOptions? options]) {
    throw UnimplementedError();
  }
}

class MockRTCPeerConnection implements RTCPeerConnection {
  @override
  Function(RTCSignalingState state)? onSignalingState;

  @override
  Function(RTCPeerConnectionState state)? onConnectionState;

  @override
  Function(RTCIceGatheringState state)? onIceGatheringState;

  @override
  Function(RTCIceConnectionState state)? onIceConnectionState;

  @override
  Function(RTCIceCandidate candidate)? onIceCandidate;

  @override
  Function(MediaStream stream)? onAddStream;

  @override
  Function(MediaStream stream)? onRemoveStream;

  @override
  Function(MediaStream stream, MediaStreamTrack track)? onAddTrack;

  @override
  Function(MediaStream stream, MediaStreamTrack track)? onRemoveTrack;

  @override
  Function(RTCDataChannel channel)? onDataChannel;

  @override
  Function()? onRenegotiationNeeded;

  @override
  Function(RTCTrackEvent event)? onTrack;

  @override
  RTCSignalingState? get signalingState => throw UnimplementedError();

  @override
  Future<RTCSignalingState?> getSignalingState() async {
    return signalingState;
  }

  @override
  // value doesn't matter we do onIceConnectionState.call manually
  RTCIceGatheringState? get iceGatheringState =>
      RTCIceGatheringState.RTCIceGatheringStateComplete;

  @override
  Future<RTCIceGatheringState?> getIceGatheringState() async {
    return iceGatheringState;
  }

  @override
  // value doesn't matter we do onIceConnectionState.call manually
  RTCIceConnectionState? get iceConnectionState =>
      RTCIceConnectionState.RTCIceConnectionStateNew;

  @override
  Future<RTCIceConnectionState?> getIceConnectionState() async {
    return iceConnectionState;
  }

  @override
  RTCPeerConnectionState? get connectionState => throw UnimplementedError();

  @override
  Future<RTCPeerConnectionState?> getConnectionState() async {
    return connectionState;
  }

  @override
  Future<void> dispose() async {
    // Mock implementation for disposing the connection
    Logs().i('Mock: Disposing RTCPeerConnection');
  }

  @override
  Map<String, dynamic> get getConfiguration => throw UnimplementedError();

  @override
  Future<void> setConfiguration(Map<String, dynamic> configuration) async {
    // Mock implementation for setting configuration
    Logs().i('Mock: Setting RTCPeerConnection configuration');
  }

  @override
  Future<RTCSessionDescription> createOffer([
    Map<String, dynamic>? constraints,
  ]) {
    // Mock implementation for creating an offer
    Logs().i('Mock: Creating offer');
    return Future.value(RTCSessionDescription('', ''));
  }

  @override
  Future<RTCSessionDescription> createAnswer([
    Map<String, dynamic>? constraints,
  ]) {
    // Mock implementation for creating an answer
    Logs().i('Mock: Creating answer');
    return Future.value(RTCSessionDescription('', ''));
  }

  @override
  Future<void> addStream(MediaStream stream) async {
    // Mock implementation for adding a stream
    Logs().i('Mock: Adding stream');
  }

  @override
  Future<void> removeStream(MediaStream stream) async {
    // Mock implementation for removing a stream
    Logs().i('Mock: Removing stream');
  }

  @override
  Future<RTCSessionDescription?> getLocalDescription() async {
    // Mock implementation for getting local description
    Logs().i('Mock: Getting local description');
    return RTCSessionDescription('', '');
  }

  @override
  Future<void> setLocalDescription(RTCSessionDescription description) async {
    // Mock implementation for setting local description
    Logs().i('Mock: Setting local description');
  }

  @override
  Future<RTCSessionDescription?> getRemoteDescription() async {
    // Mock implementation for getting remote description
    Logs().i('Mock: Getting remote description');
    return RTCSessionDescription('', '');
  }

  @override
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    // Mock implementation for setting remote description
    Logs().i('Mock: Setting remote description');
  }

  @override
  Future<void> addCandidate(RTCIceCandidate candidate) async {
    // Mock implementation for adding a candidate
    Logs().i('Mock: Adding ICE candidate');
  }

  @override
  Future<List<StatsReport>> getStats([MediaStreamTrack? track]) async {
    // Mock implementation for getting stats
    Logs().i('Mock: Getting stats');
    return [];
  }

  @override
  List<MediaStream?> getLocalStreams() {
    // Mock implementation for getting local streams
    Logs().i('Mock: Getting local streams');
    return [];
  }

  @override
  List<MediaStream?> getRemoteStreams() {
    // Mock implementation for getting remote streams
    Logs().i('Mock: Getting remote streams');
    return [];
  }

  @override
  Future<RTCDataChannel> createDataChannel(
    String label,
    RTCDataChannelInit dataChannelDict,
  ) async {
    // Mock implementation for creating a data channel
    Logs().i('Mock: Creating data channel');
    return MockRTCDataChannel();
  }

  @override
  Future<void> restartIce() async {
    // Mock implementation for restarting ICE
    Logs().i('Mock: Restarting ICE');
  }

  @override
  Future<void> close() async {
    // Mock implementation for closing the connection
    Logs().i('Mock: Closing RTCPeerConnection');
  }

  @override
  RTCDTMFSender createDtmfSender(MediaStreamTrack track) {
    // Mock implementation for creating a DTMF sender
    Logs().i('Mock: Creating DTMF sender');
    return MockRTCDTMFSender();
  }

  @override
  Future<List<RTCRtpSender>> getSenders() async {
    // Mock implementation for getting senders
    Logs().i('Mock: Getting senders');
    return [];
  }

  @override
  Future<List<RTCRtpReceiver>> getReceivers() async {
    // Mock implementation for getting receivers
    Logs().i('Mock: Getting receivers');
    return [];
  }

  @override
  Future<List<RTCRtpTransceiver>> getTransceivers() async {
    // Mock implementation for getting transceivers
    Logs().i('Mock: Getting transceivers');
    return [];
  }

  @override
  Future<RTCRtpSender> addTrack(
    MediaStreamTrack track, [
    MediaStream? stream,
  ]) async {
    // Mock implementation for adding a track
    Logs().i('Mock: Adding track');
    return MockRTCRtpSender();
  }

  @override
  Future<bool> removeTrack(RTCRtpSender sender) async {
    // Mock implementation for removing a track
    Logs().i('Mock: Removing track');
    return true;
  }

  @override
  Future<RTCRtpTransceiver> addTransceiver({
    MediaStreamTrack? track,
    RTCRtpMediaType? kind,
    RTCRtpTransceiverInit? init,
  }) async {
    // Mock implementation for adding a transceiver
    Logs().i('Mock: Adding transceiver');
    return MockRTCRtpTransceiver();
  }

  @override
  Future<List<RTCRtpReceiver>> get receivers => throw UnimplementedError();

  @override
  Future<List<RTCRtpSender>> get senders => throw UnimplementedError();

  @override
  Future<List<RTCRtpTransceiver>> get transceivers =>
      throw UnimplementedError();
}

class MockRTCRtpTransceiver implements RTCRtpTransceiver {
  @override
  Future<TransceiverDirection?> getCurrentDirection() async {
    // Mock implementation for getting current direction
    Logs().i('Mock: Getting current direction');
    return TransceiverDirection.SendRecv;
  }

  @override
  Future<void> setDirection(TransceiverDirection direction) async {
    // Mock implementation for setting direction
    Logs().i('Mock: Setting direction');
  }

  @override
  Future<TransceiverDirection> getDirection() async {
    // Mock implementation for getting direction
    Logs().i('Mock: Getting direction');
    return TransceiverDirection.SendRecv;
  }

  @override
  Future<void> setCodecPreferences(List<RTCRtpCodecCapability> codecs) async {
    // Mock implementation for setting codec preferences
    Logs().i('Mock: Setting codec preferences');
  }

  @override
  String get mid => 'mock_mid';

  @override
  RTCRtpSender get sender => MockRTCRtpSender();

  @override
  RTCRtpReceiver get receiver => MockRTCRtpReceiver();

  bool get stopped => false;

  @override
  String get transceiverId => 'mock_transceiver_id';

  @override
  Future<void> stop() async {
    // Mock implementation for stopping transceiver
    Logs().i('Mock: Stopping transceiver');
  }

  @override
  TransceiverDirection get currentDirection {
    // Deprecated method, should be replaced with `await getCurrentDirection`
    throw UnimplementedError(
      'Need to be call asynchronously from native SDK, so the method is deprecated',
    );
  }

  @override
  bool get stoped => throw UnimplementedError();
}

class MockRTCRtpSender implements RTCRtpSender {
  @override
  Future<void> dispose() {
    throw UnimplementedError();
  }

  @override
  RTCDTMFSender get dtmfSender => throw UnimplementedError();

  @override
  Future<List<StatsReport>> getStats() {
    throw UnimplementedError();
  }

  @override
  bool get ownsTrack => throw UnimplementedError();

  @override
  RTCRtpParameters get parameters => throw UnimplementedError();

  @override
  Future<void> replaceTrack(MediaStreamTrack? track) {
    throw UnimplementedError();
  }

  @override
  String get senderId => throw UnimplementedError();

  @override
  Future<bool> setParameters(RTCRtpParameters parameters) {
    throw UnimplementedError();
  }

  @override
  Future<void> setStreams(List<MediaStream> streams) {
    throw UnimplementedError();
  }

  @override
  Future<void> setTrack(MediaStreamTrack? track, {bool takeOwnership = true}) {
    throw UnimplementedError();
  }

  @override
  MediaStreamTrack? get track => throw UnimplementedError();
  // Mock implementation for RTCRtpSender
}

class MockRTCRtpReceiver implements RTCRtpReceiver {
  @override
  Function(RTCRtpReceiver rtpReceiver, RTCRtpMediaType mediaType)?
      onFirstPacketReceived;

  @override
  Future<List<StatsReport>> getStats() {
    throw UnimplementedError();
  }

  @override
  RTCRtpParameters get parameters => throw UnimplementedError();

  @override
  String get receiverId => throw UnimplementedError();

  @override
  MediaStreamTrack? get track => throw UnimplementedError();
  // Mock implementation for RTCRtpReceiver
}

typedef StreamTrackCallback = void Function();

class MockMediaStreamTrack implements MediaStreamTrack {
  @override
  String? get id => 'mock_id';

  @override
  String? get label => 'mock_label';

  @override
  String? get kind => 'mock_kind';

  @override
  StreamTrackCallback? onMute;

  @override
  StreamTrackCallback? onUnMute;

  @override
  StreamTrackCallback? onEnded;

  @override
  bool get enabled => true;

  @override
  set enabled(bool b) {
    // Mock implementation for setting enable state
    Logs().i('Mock: Setting MediaStreamTrack enable state');
  }

  @override
  bool? get muted => false;

  @override
  Map<String, dynamic> getConstraints() {
    throw UnimplementedError();
  }

  @override
  Future<void> applyConstraints([Map<String, dynamic>? constraints]) async {
    throw UnimplementedError();
  }

  @override
  Future<MediaStreamTrack> clone() async {
    throw UnimplementedError();
  }

  @override
  Future<void> stop() async {
    // Mock implementation for stopping the track
    Logs().i('Mock: Stopping MediaStreamTrack');
  }

  @override
  Map<String, dynamic> getSettings() {
    throw UnimplementedError();
  }

  @override
  Future<bool> switchCamera() async {
    throw UnimplementedError();
  }

  @override
  Future<void> adaptRes(int width, int height) async {
    throw UnimplementedError();
  }

  @override
  void enableSpeakerphone(bool enable) {
    throw UnimplementedError();
  }

  @override
  Future<ByteBuffer> captureFrame() async {
    throw UnimplementedError();
  }

  @override
  Future<bool> hasTorch() async {
    throw UnimplementedError();
  }

  @override
  Future<void> setTorch(bool torch) async {
    throw UnimplementedError();
  }

  @override
  @Deprecated('use stop() instead')
  Future<void> dispose() async {
    // Mock implementation for disposing the track
    Logs().i('Mock: Disposing MediaStreamTrack');
  }

  @override
  String toString() {
    return 'Track(id: $id, kind: $kind, label: $label, enabled: $enabled, muted: $muted)';
  }
}

class MockRTCDTMFSender implements RTCDTMFSender {
  @override
  Future<void> insertDTMF(
    String tones, {
    int duration = 100,
    int interToneGap = 70,
  }) async {
    // Mock implementation for inserting DTMF tones
    Logs().i(
      'Mock: Inserting DTMF tones: $tones, Duration: $duration, InterToneGap: $interToneGap',
    );
  }

  @override
  @Deprecated('Use method insertDTMF instead')
  Future<void> sendDtmf(
    String tones, {
    int duration = 100,
    int interToneGap = 70,
  }) async {
    return insertDTMF(tones, duration: duration, interToneGap: interToneGap);
  }

  @override
  Future<bool> canInsertDtmf() async {
    // Mock implementation for checking if DTMF can be inserted
    Logs().i('Mock: Checking if DTMF can be inserted');
    return true;
  }
}

class MockRTCDataChannel implements RTCDataChannel {
  @override
  Function(RTCDataChannelState state)? onDataChannelState;

  @override
  Function(RTCDataChannelMessage data)? onMessage;

  @override
  Function(int currentAmount, int changedAmount)? onBufferedAmountChange;

  @override
  Function(int currentAmount)? onBufferedAmountLow;

  @override
  RTCDataChannelState? get state => RTCDataChannelState.RTCDataChannelOpen;

  @override
  int? get id => 1;

  @override
  String? get label => 'mock_label';

  @override
  int? get bufferedAmount => 0;

  @override
  int? bufferedAmountLowThreshold;

  @override
  late Stream<RTCDataChannelState> stateChangeStream;

  @override
  late Stream<RTCDataChannelMessage> messageStream;

  @override
  Future<void> send(RTCDataChannelMessage message) async {
    // Mock implementation for sending a message
    Logs().i('Mock: Sending RTCDataChannelMessage: $message');
  }

  @override
  Future<void> close() async {
    // Mock implementation for closing the data channel
    Logs().i('Mock: Closing RTCDataChannel');
  }

  @override
  Future<int> getBufferedAmount() async {
    return 0;
  }
}

class MockMediaStream implements MediaStream {
  final String _id;
  final String _ownerTag;
  bool _isActive = true; // Initially set as active

  MockMediaStream(this._id, this._ownerTag);

  @override
  Function(MediaStreamTrack track)? onAddTrack;

  @override
  Function(MediaStreamTrack track)? onRemoveTrack;

  @override
  String get id => _id;

  @override
  String get ownerTag => _ownerTag;

  @override
  bool? get active => _isActive;

  @override
  Future<void> getMediaTracks() async {
    // Mock implementation for getting media tracks
    Logs().i('Mock: Getting media tracks');
  }

  @override
  Future<void> addTrack(
    MediaStreamTrack track, {
    bool addToNative = true,
  }) async {
    // Mock implementation for adding a track
    Logs().i('Mock: Adding track to MediaStream: $track');
    onAddTrack?.call(track);
  }

  @override
  Future<void> removeTrack(
    MediaStreamTrack track, {
    bool removeFromNative = true,
  }) async {
    // Mock implementation for removing a track
    Logs().i('Mock: Removing track from MediaStream: $track');
    onRemoveTrack?.call(track);
  }

  @override
  List<MediaStreamTrack> getTracks() {
    // Mock implementation for getting all tracks
    Logs().i('Mock: Getting all tracks');
    return [];
  }

  @override
  List<MediaStreamTrack> getAudioTracks() {
    // Mock implementation for getting audio tracks
    Logs().i('Mock: Getting audio tracks');
    return [];
  }

  @override
  List<MediaStreamTrack> getVideoTracks() {
    // Mock implementation for getting video tracks
    Logs().i('Mock: Getting video tracks');
    return [];
  }

  @override
  MediaStreamTrack? getTrackById(String trackId) {
    // Mock implementation for getting a track by ID
    Logs().i('Mock: Getting track by ID: $trackId');
    return null;
  }

  @override
  Future<MediaStream> clone() async {
    // Mock implementation for cloning the media stream
    Logs().i('Mock: Cloning MediaStream');
    return MockMediaStream('${_id}_clone', _ownerTag);
  }

  @override
  Future<void> dispose() async {
    // Mock implementation for disposing the media stream
    Logs().i('Mock: Disposing MediaStream');
    _isActive = false;
  }
}

class MockVideoRenderer implements VideoRenderer {
  @override
  Function? onResize;
  @override
  Function? onFirstFrameRendered;
  final int _videoWidth = 0;
  final int _videoHeight = 0;
  bool _muted = false;
  final bool _renderVideo = true;
  int? _textureId;
  MediaStream? _srcObject;

  @override
  int get videoWidth => _videoWidth;

  @override
  int get videoHeight => _videoHeight;

  @override
  bool get muted => _muted;

  @override
  set muted(bool mute) {
    _muted = mute;
    // Mock implementation for muting/unmuting
    Logs().i('Mock: Setting mute state: $_muted');
  }

  @override
  Future<bool> audioOutput(String deviceId) async {
    // Mock implementation for changing audio output
    Logs().i('Mock: Changing audio output to device ID: $deviceId');
    return true; // Mocking successful audio output change
  }

  @override
  bool get renderVideo => _renderVideo;

  @override
  int? get textureId => _textureId;

  @override
  Future<void> initialize() async {
    // Mock implementation for initialization
    Logs().i('Mock: Initializing VideoRenderer');
  }

  @override
  MediaStream? get srcObject => _srcObject;

  @override
  set srcObject(MediaStream? stream) {
    _srcObject = stream;
    // Mock implementation for setting source object
    Logs().i('Mock: Setting source object for VideoRenderer');
  }

  @override
  Future<void> dispose() async {
    // Mock implementation for disposing VideoRenderer
    Logs().i('Mock: Disposing VideoRenderer');
  }

  @override
  // TODO: implement videoValue
  RTCVideoValue get videoValue => RTCVideoValue.empty;
}
