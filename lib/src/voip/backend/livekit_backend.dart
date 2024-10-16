import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/crypto/crypto.dart';
import 'package:matrix/src/voip/models/call_membership.dart';

class LiveKitBackend extends CallBackend {
  final String livekitServiceUrl;
  final String livekitAlias;

  /// A delay after a member leaves before we create and publish a new key, because people
  /// tend to leave calls at the same time
  final Duration makeKeyDelay;

  /// The delay between creating and sending a new key and starting to encrypt with it. This gives others
  /// a chance to receive the new key to minimise the chance they don't get media they can't decrypt.
  /// The total time between a member leaving and the call switching to new keys is therefore
  /// makeKeyDelay + useKeyDelay
  final Duration useKeyDelay;

  @override
  final bool e2eeEnabled;

  LiveKitBackend({
    required this.livekitServiceUrl,
    required this.livekitAlias,
    super.type = 'livekit',
    this.e2eeEnabled = true,
    this.makeKeyDelay = CallTimeouts.makeKeyDelay,
    this.useKeyDelay = CallTimeouts.useKeyDelay,
  });

  Timer? _memberLeaveEncKeyRotateDebounceTimer;

  /// participant:keyIndex:keyBin
  final Map<CallParticipant, Map<int, Uint8List>> _encryptionKeysMap = {};

  final List<Future> _setNewKeyTimeouts = [];

  int _indexCounter = 0;

  /// used to send the key again incase someone `onCallEncryptionKeyRequest` but don't just send
  /// the last one because you also cycle back in your window which means you
  /// could potentially end up sharing a past key
  int get latestLocalKeyIndex => _latestLocalKeyIndex;
  int _latestLocalKeyIndex = 0;

  /// the key currently being used by the local cryptor, can possibly not be the latest
  /// key, check `latestLocalKeyIndex` for latest key
  int get currentLocalKeyIndex => _currentLocalKeyIndex;
  int _currentLocalKeyIndex = 0;

  Map<int, Uint8List>? _getKeysForParticipant(CallParticipant participant) {
    return _encryptionKeysMap[participant];
  }

  /// always chooses the next possible index, we cycle after 16 because
  /// no real adv with infinite list
  int _getNewEncryptionKeyIndex() {
    final newIndex = _indexCounter % 16;
    _indexCounter++;
    return newIndex;
  }

  @override
  Future<void> preShareKey(GroupCallSession groupCall) async {
    await groupCall.onMemberStateChanged();
    await _changeEncryptionKey(groupCall, groupCall.participants, false);
  }

  /// makes a new e2ee key for local user and sets it with a delay if specified
  /// used on first join and when someone leaves
  ///
  /// also does the sending for you
  Future<void> _makeNewSenderKey(
      GroupCallSession groupCall, bool delayBeforeUsingKeyOurself) async {
    final key = secureRandomBytes(32);
    final keyIndex = _getNewEncryptionKeyIndex();
    Logs().i('[VOIP E2EE] Generated new key $key at index $keyIndex');

    await _setEncryptionKey(
      groupCall,
      groupCall.localParticipant!,
      keyIndex,
      key,
      delayBeforeUsingKeyOurself: delayBeforeUsingKeyOurself,
      send: true,
    );
  }

  /// also does the sending for you
  Future<void> _ratchetLocalParticipantKey(
    GroupCallSession groupCall,
    List<CallParticipant> sendTo,
  ) async {
    final keyProvider = groupCall.voip.delegate.keyProvider;

    if (keyProvider == null) {
      throw MatrixSDKVoipException(
          '_ratchetKey called but KeyProvider was null');
    }

    final myKeys = _encryptionKeysMap[groupCall.localParticipant];

    if (myKeys == null || myKeys.isEmpty) {
      await _makeNewSenderKey(groupCall, false);
      return;
    }

    Uint8List? ratchetedKey;

    while (ratchetedKey == null || ratchetedKey.isEmpty) {
      Logs().i('[VOIP E2EE] Ignoring empty ratcheted key');
      ratchetedKey = await keyProvider.onRatchetKey(
        groupCall.localParticipant!,
        latestLocalKeyIndex,
      );
    }

    Logs().i(
        '[VOIP E2EE] Ratched latest key to $ratchetedKey at idx $latestLocalKeyIndex');

    await _setEncryptionKey(
      groupCall,
      groupCall.localParticipant!,
      latestLocalKeyIndex,
      ratchetedKey,
      delayBeforeUsingKeyOurself: false,
      send: true,
      sendTo: sendTo,
    );
  }

  Future<void> _changeEncryptionKey(
    GroupCallSession groupCall,
    List<CallParticipant> anyJoined,
    bool delayBeforeUsingKeyOurself,
  ) async {
    if (!e2eeEnabled) return;
    if (groupCall.voip.enableSFUE2EEKeyRatcheting) {
      await _ratchetLocalParticipantKey(groupCall, anyJoined);
    } else {
      await _makeNewSenderKey(groupCall, delayBeforeUsingKeyOurself);
    }
  }

  /// sets incoming keys and also sends the key if it was for the local user
  /// if sendTo is null, its sent to all _participants, see `_sendEncryptionKeysEvent`
  Future<void> _setEncryptionKey(
    GroupCallSession groupCall,
    CallParticipant participant,
    int encryptionKeyIndex,
    Uint8List encryptionKeyBin, {
    bool delayBeforeUsingKeyOurself = false,
    bool send = false,
    List<CallParticipant>? sendTo,
  }) async {
    final encryptionKeys =
        _encryptionKeysMap[participant] ?? <int, Uint8List>{};

    encryptionKeys[encryptionKeyIndex] = encryptionKeyBin;
    _encryptionKeysMap[participant] = encryptionKeys;
    if (participant.isLocal) {
      _latestLocalKeyIndex = encryptionKeyIndex;
    }

    if (send) {
      await _sendEncryptionKeysEvent(
        groupCall,
        encryptionKeyIndex,
        sendTo: sendTo,
      );
    }

    if (delayBeforeUsingKeyOurself) {
      // now wait for the key to propogate and then set it, hopefully users can
      // stil decrypt everything
      final useKeyTimeout = Future.delayed(useKeyDelay, () async {
        Logs().i(
            '[VOIP E2EE] setting key changed event for ${participant.id} idx $encryptionKeyIndex key $encryptionKeyBin');
        await groupCall.voip.delegate.keyProvider?.onSetEncryptionKey(
            participant, encryptionKeyBin, encryptionKeyIndex);
        if (participant.isLocal) {
          _currentLocalKeyIndex = encryptionKeyIndex;
        }
      });
      _setNewKeyTimeouts.add(useKeyTimeout);
    } else {
      Logs().i(
          '[VOIP E2EE] setting key changed event for ${participant.id} idx $encryptionKeyIndex key $encryptionKeyBin');
      await groupCall.voip.delegate.keyProvider?.onSetEncryptionKey(
          participant, encryptionKeyBin, encryptionKeyIndex);
      if (participant.isLocal) {
        _currentLocalKeyIndex = encryptionKeyIndex;
      }
    }
  }

  /// sends the enc key to the devices using todevice, passing a list of
  /// sendTo only sends events to them
  /// setting keyIndex to null will send the latestKey
  Future<void> _sendEncryptionKeysEvent(
    GroupCallSession groupCall,
    int keyIndex, {
    List<CallParticipant>? sendTo,
  }) async {
    final myKeys = _getKeysForParticipant(groupCall.localParticipant!);
    final myLatestKey = myKeys?[keyIndex];

    final sendKeysTo =
        sendTo ?? groupCall.participants.where((p) => !p.isLocal);

    if (myKeys == null || myLatestKey == null) {
      Logs().w(
          '[VOIP E2EE] _sendEncryptionKeysEvent Tried to send encryption keys event but no keys found!');
      await _makeNewSenderKey(groupCall, false);
      await _sendEncryptionKeysEvent(
        groupCall,
        keyIndex,
        sendTo: sendTo,
      );
      return;
    }

    try {
      final keyContent = EncryptionKeysEventContent(
        [EncryptionKeyEntry(keyIndex, base64Encode(myLatestKey))],
        groupCall.groupCallId,
      );
      final Map<String, Object> data = {
        ...keyContent.toJson(),
        // used to find group call in groupCalls when ToDeviceEvent happens,
        // plays nicely with backwards compatibility for mesh calls
        'conf_id': groupCall.groupCallId,
        'device_id': groupCall.client.deviceID!,
        'room_id': groupCall.room.id,
      };
      await _sendToDeviceEvent(
        groupCall,
        sendTo ?? sendKeysTo.toList(),
        data,
        EventTypes.GroupCallMemberEncryptionKeys,
      );
    } catch (e, s) {
      Logs().e('[VOIP] Failed to send e2ee keys, retrying', e, s);
      await _sendEncryptionKeysEvent(
        groupCall,
        keyIndex,
        sendTo: sendTo,
      );
    }
  }

  Future<void> _sendToDeviceEvent(
    GroupCallSession groupCall,
    List<CallParticipant> remoteParticipants,
    Map<String, Object> data,
    String eventType,
  ) async {
    if (remoteParticipants.isEmpty) return;
    Logs().v(
        '[VOIP] _sendToDeviceEvent: sending ${data.toString()} to ${remoteParticipants.map((e) => e.id)} ');
    final txid =
        VoIP.customTxid ?? groupCall.client.generateUniqueTransactionId();
    final mustEncrypt =
        groupCall.room.encrypted && groupCall.client.encryptionEnabled;

    // could just combine the two but do not want to rewrite the enc thingy
    // wrappers here again.
    final List<DeviceKeys> mustEncryptkeysToSendTo = [];
    final Map<String, Map<String, Map<String, Object>>> unencryptedDataToSend =
        {};

    for (final participant in remoteParticipants) {
      if (participant.deviceId == null) continue;
      if (mustEncrypt) {
        await groupCall.client.userDeviceKeysLoading;
        final deviceKey = groupCall.client.userDeviceKeys[participant.userId]
            ?.deviceKeys[participant.deviceId];
        if (deviceKey != null) {
          mustEncryptkeysToSendTo.add(deviceKey);
        }
      } else {
        unencryptedDataToSend.addAll({
          participant.userId: {participant.deviceId!: data}
        });
      }
    }

    // prepped data, now we send
    if (mustEncrypt) {
      await groupCall.client.sendToDeviceEncrypted(
        mustEncryptkeysToSendTo,
        eventType,
        data,
      );
    } else {
      await groupCall.client.sendToDevice(
        eventType,
        txid,
        unencryptedDataToSend,
      );
    }
  }

  @override
  Map<String, Object?> toJson() {
    return {
      'type': type,
      'livekit_service_url': livekitServiceUrl,
      'livekit_alias': livekitAlias,
    };
  }

  @override
  Future<void> requestEncrytionKey(
    GroupCallSession groupCall,
    List<CallParticipant> remoteParticipants,
  ) async {
    final Map<String, Object> data = {
      'conf_id': groupCall.groupCallId,
      'device_id': groupCall.client.deviceID!,
      'room_id': groupCall.room.id,
    };

    await _sendToDeviceEvent(
      groupCall,
      remoteParticipants,
      data,
      EventTypes.GroupCallMemberEncryptionKeysRequest,
    );
  }

  @override
  Future<void> onCallEncryption(
    GroupCallSession groupCall,
    String userId,
    String deviceId,
    Map<String, dynamic> content,
  ) async {
    if (!e2eeEnabled) {
      Logs().w('[VOIP] got sframe key but we do not support e2ee');
      return;
    }
    final keyContent = EncryptionKeysEventContent.fromJson(content);

    final callId = keyContent.callId;
    final p =
        CallParticipant(groupCall.voip, userId: userId, deviceId: deviceId);

    if (keyContent.keys.isEmpty) {
      Logs().w(
          '[VOIP E2EE] Received m.call.encryption_keys where keys is empty: callId=$callId');
      return;
    } else {
      Logs().i(
          '[VOIP E2EE]: onCallEncryption, got keys from ${p.id} ${keyContent.toJson()}');
    }

    for (final key in keyContent.keys) {
      final encryptionKey = key.key;
      final encryptionKeyIndex = key.index;
      await _setEncryptionKey(
        groupCall,
        p,
        encryptionKeyIndex,
        // base64Decode here because we receive base64Encoded version
        base64Decode(encryptionKey),
        delayBeforeUsingKeyOurself: false,
        send: false,
      );
    }
  }

  @override
  Future<void> onCallEncryptionKeyRequest(
    GroupCallSession groupCall,
    String userId,
    String deviceId,
    Map<String, dynamic> content,
  ) async {
    if (!e2eeEnabled) {
      Logs().w('[VOIP] got sframe key request but we do not support e2ee');
      return;
    }
    final mems = groupCall.room.getCallMembershipsForUser(userId);
    if (mems
        .where(
          (mem) =>
              mem.callId == groupCall.groupCallId &&
              mem.userId == userId &&
              mem.deviceId == deviceId &&
              !mem.isExpired &&
              // sanity checks
              mem.backend.type == groupCall.backend.type &&
              mem.roomId == groupCall.room.id &&
              mem.application == groupCall.application,
        )
        .isNotEmpty) {
      Logs().d(
          '[VOIP] onCallEncryptionKeyRequest: request checks out, sending key on index: $latestLocalKeyIndex to $userId:$deviceId');
      await _sendEncryptionKeysEvent(
        groupCall,
        _latestLocalKeyIndex,
        sendTo: [
          CallParticipant(
            groupCall.voip,
            userId: userId,
            deviceId: deviceId,
          )
        ],
      );
    }
  }

  @override
  Future<void> onNewParticipant(
    GroupCallSession groupCall,
    List<CallParticipant> anyJoined,
  ) =>
      _changeEncryptionKey(groupCall, anyJoined, true);

  @override
  Future<void> onLeftParticipant(
    GroupCallSession groupCall,
    List<CallParticipant> anyLeft,
  ) async {
    _encryptionKeysMap.removeWhere((key, value) => anyLeft.contains(key));

    // debounce it because people leave at the same time
    if (_memberLeaveEncKeyRotateDebounceTimer != null) {
      _memberLeaveEncKeyRotateDebounceTimer!.cancel();
    }
    _memberLeaveEncKeyRotateDebounceTimer = Timer(makeKeyDelay, () async {
      await _makeNewSenderKey(groupCall, true);
    });
  }

  @override
  Future<void> dispose(GroupCallSession groupCall) async {
    // only remove our own, to save requesting if we join again, yes the other side
    // will send it anyway but welp
    _encryptionKeysMap.remove(groupCall.localParticipant!);
    _currentLocalKeyIndex = 0;
    _latestLocalKeyIndex = 0;
    _memberLeaveEncKeyRotateDebounceTimer?.cancel();
  }

  @override
  List<Map<String, String>>? getCurrentFeeds() {
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiveKitBackend &&
          type == other.type &&
          livekitServiceUrl == other.livekitServiceUrl &&
          livekitAlias == other.livekitAlias;

  @override
  int get hashCode => Object.hash(
        type.hashCode,
        livekitServiceUrl.hashCode,
        livekitAlias.hashCode,
      );

  /// get everything else from your livekit sdk in your client
  @override
  Future<WrappedMediaStream?> initLocalStream(GroupCallSession groupCall,
      {WrappedMediaStream? stream}) async {
    return null;
  }

  @override
  CallParticipant? get activeSpeaker => null;

  /// these are unimplemented on purpose so that you know you have
  /// used the wrong method
  @override
  bool get isLocalVideoMuted =>
      throw UnimplementedError('Use livekit sdk for this');

  @override
  bool get isMicrophoneMuted =>
      throw UnimplementedError('Use livekit sdk for this');

  @override
  WrappedMediaStream? get localScreenshareStream =>
      throw UnimplementedError('Use livekit sdk for this');

  @override
  WrappedMediaStream? get localUserMediaStream =>
      throw UnimplementedError('Use livekit sdk for this');

  @override
  List<WrappedMediaStream> get screenShareStreams =>
      throw UnimplementedError('Use livekit sdk for this');

  @override
  List<WrappedMediaStream> get userMediaStreams =>
      throw UnimplementedError('Use livekit sdk for this');

  @override
  Future<void> setDeviceMuted(
      GroupCallSession groupCall, bool muted, MediaInputKind kind) async {
    return;
  }

  @override
  Future<void> setScreensharingEnabled(GroupCallSession groupCall, bool enabled,
      String desktopCapturerSourceId) async {
    return;
  }

  @override
  Future<void> setupP2PCallWithNewMember(GroupCallSession groupCall,
      CallParticipant rp, CallMembership mem) async {
    return;
  }

  @override
  Future<void> setupP2PCallsWithExistingMembers(
      GroupCallSession groupCall) async {
    return;
  }

  @override
  Future<void> updateMediaDeviceForCalls() async {
    return;
  }
}
