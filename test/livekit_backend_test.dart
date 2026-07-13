// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:typed_data';

import 'package:matrix/matrix.dart';
import 'package:test/test.dart';

import 'fake_client.dart';
import 'webrtc_stub.dart';

class _CountingEncryptionKeyProvider implements EncryptionKeyProvider {
  final List<int> localKeyIndices = [];

  @override
  Future<void> onSetEncryptionKey(
    CallParticipant participant,
    Uint8List key,
    int index,
  ) async {
    if (participant.isLocal) {
      localKeyIndices.add(index);
    }
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

class _CountingWebRTCDelegate extends MockWebRTCDelegate {
  _CountingWebRTCDelegate(this._keyProvider);

  final EncryptionKeyProvider _keyProvider;

  @override
  EncryptionKeyProvider get keyProvider => _keyProvider;
}

void main() {
  group('LiveKitBackend', () {
    late Client client;
    late Room room;
    late _CountingEncryptionKeyProvider keyProvider;
    late VoIP voip;
    late LiveKitBackend backend;
    late GroupCallSession groupCall;

    setUp(() async {
      client = await getClient();
      await client.abortSync();
      room = client.getRoomById('!calls:example.com')!;

      keyProvider = _CountingEncryptionKeyProvider();
      voip = VoIP(
        client,
        _CountingWebRTCDelegate(keyProvider),
        timeouts: CallTimeouts(
          makeKeyOnLeaveDelay: Duration(milliseconds: 10),
          makeKeyOnJoinDelay: Duration(seconds: 1),
          useKeyDelay: Duration(milliseconds: 10),
        ),
      );
      backend = LiveKitBackend(
        livekitServiceUrl: 'https://livekit.example.com',
        livekitAlias: 'test-room',
      );
      groupCall = GroupCallSession.withAutoGenId(
        room,
        voip,
        backend,
        'm.call',
        'm.room',
        'livekit-stack-overflow-regression',
      );
    });

    test(
      'dispose clears the recent-key debounce after local keys are removed',
      () async {
        await backend.preShareKey(groupCall);

        expect(backend.latestLocalKeyIndex, 0);
        expect(backend.currentLocalKeyIndex, 0);
        expect(keyProvider.localKeyIndices, [0]);

        await backend.dispose(groupCall);

        final rejoinedGroupCall = GroupCallSession.withAutoGenId(
          room,
          voip,
          backend,
          'm.call',
          'm.room',
          'livekit-rejoin-after-dispose',
        );

        await expectLater(backend.preShareKey(rejoinedGroupCall), completes);

        expect(
          backend.latestLocalKeyIndex,
          1,
          reason:
              'after dispose the backend must generate a fresh key instead of trying to resend a missing one',
        );
        expect(backend.currentLocalKeyIndex, 1);
        expect(keyProvider.localKeyIndices, [0, 1]);
      },
    );
  });
}
