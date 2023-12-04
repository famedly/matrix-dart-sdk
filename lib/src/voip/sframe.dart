import 'dart:typed_data';

import 'package:webrtc_interface/webrtc_interface.dart';

import 'package:matrix/matrix.dart';

const String matrixWebRtcRatchetSalt = 'matrix-webrtc-ratchet-salt';

class FrameCryptorWrapper {
  FrameCryptorWrapper(this.frameCryptor, this.keyProvider);
  final FrameCryptor frameCryptor;
  final KeyProvider keyProvider;
}

extension SframeExt on VoIP {
  Future<KeyProvider> _initKeyProvider() async {
    return await delegate.frameCryptorFactory!.createDefaultKeyProvider(
      KeyProviderOptions(
        sharedKey: false,
        ratchetSalt: Uint8List.fromList(matrixWebRtcRatchetSalt.codeUnits),
        ratchetWindowSize: 16,
      ),
    );
  }

  Future<void> setSframeEnabled(String callId, bool enabled) async {
    frameCryptors.forEach((key, fc) async {
      if (key.startsWith(callId)) {
        await fc.frameCryptor.setEnabled(enabled);
      }
    });
  }

  Future<void> disposeSFrame(String callId) async {
    frameCryptors.removeWhere((key, fc) {
      if (key.startsWith(callId)) {
        fc.frameCryptor.dispose();
        fc.keyProvider.dispose();
        return true;
      }
      return false;
    });
  }

  Future<void> handleAddRtpSender(
    String callId,
    RTCRtpSender sender,
    String sFrameKey,
  ) async {
    final trackId = sender.track?.id;
    final kind = sender.track?.kind;
    final id = '$callId-${kind!}_${trackId!}_sender';
    if (!frameCryptors.containsKey(id)) {
      final keyProvider = await _initKeyProvider();
      final frameCryptor =
          await delegate.frameCryptorFactory!.createFrameCryptorForRtpSender(
        participantId: id,
        sender: sender,
        algorithm: Algorithm.kAesGcm,
        keyProvider: keyProvider,
      );
      frameCryptor.onFrameCryptorStateChanged = (participantId, state) => Logs()
          .d('[VoipPlugin] Encryptor onFrameCryptorStateChanged $participantId $state');
      frameCryptors[id] = FrameCryptorWrapper(frameCryptor, keyProvider);
      await keyProvider.setKey(
        participantId: id,
        index: 0,
        key: Uint8List.fromList(sFrameKey.codeUnits),
      );
      await frameCryptor.setEnabled(true);
    }
  }

  Future<void> handleAddRtpReceiver(
    String callId,
    RTCRtpReceiver receiver,
    String sframeKey,
  ) async {
    final trackId = receiver.track?.id;
    final kind = receiver.track?.kind;
    final id = '$callId-${kind!}_${trackId!}_receiver';
    if (!frameCryptors.containsKey(id)) {
      final keyProvider = await _initKeyProvider();
      final frameCryptor =
          await delegate.frameCryptorFactory!.createFrameCryptorForRtpReceiver(
        participantId: id,
        receiver: receiver,
        algorithm: Algorithm.kAesGcm,
        keyProvider: keyProvider,
      );
      frameCryptor.onFrameCryptorStateChanged = (participantId, state) => Logs()
          .d('[VoipPlugin]Decryptor onFrameCryptorStateChanged $participantId $state');
      frameCryptors[id] = FrameCryptorWrapper(frameCryptor, keyProvider);
      await keyProvider.setKey(
        participantId: id,
        index: 0,
        key: Uint8List.fromList(sframeKey.codeUnits),
      );
      await frameCryptor.setEnabled(true);
    }
  }
}
