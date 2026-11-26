<!--
SPDX-FileCopyrightText: 2026-Present Famedly GmbH

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# MatrixRTC Calls (MSC3401)

Group calls over a LiveKit SFU per [MSC3401](https://github.com/matrix-org/matrix-spec-proposals/pull/3401), compatible with Element Call.

The SDK does the Matrix side: membership state, LiveKit credentials, E2EE key exchange and hand raising. Media is handled by a LiveKit client such as [`livekit_client`](https://pub.dev/packages/livekit_client) for Flutter. This guide uses it as the example, the same way FluffyChat does.

The extension is not exported by `package:matrix/matrix.dart`. Import it explicitly, and import LiveKit with a prefix because both packages define `Room`. `flutter_webrtc` comes with `livekit_client` and is needed for the key provider options:

```dart
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:matrix/matrix.dart';
import 'package:matrix/msc_extensions/msc3401_matrix_rtc_calls/msc_3401_matrix_rtc_calls.dart';
```

## Requirements

- The homeserver advertises a LiveKit service via `/_matrix/client/unstable/org.matrix.msc4143/rtc/transports` or `org.matrix.msc4143.rtc_foci` in `.well-known`. Check with `client.getLiveKitServiceUrls()`.
- The user may send `org.matrix.msc3401.call.member` state events: `room.hasPermissionForMatrixRtcCall`.

## Show call state in the UI

```dart
room.hasActiveMatrixRtcCall;       // Someone is in a call → show a "Join" button
room.activeMatrixRtcCallIntent;    // MatrixRtcCallIntent.video, .voice or null
room.getActiveMatrixRtcMembers();  // Non-expired members
room.ownMatrixRtcMembership;       // Our own membership, if any
```

## Join with LiveKit

```dart
// 1. Set up E2EE with per-participant keys. kHKDF and the salt match the key
//    derivation of Element Call (LiveKit JS SDK).
final keyProviderOptions = rtc.KeyProviderOptions(
  sharedKey: false,
  ratchetSalt: Uint8List.fromList('LKFrameEncryptionKey'.codeUnits),
  ratchetWindowSize: 0,
  discardFrameWhenCryptorNotReady: true,
  keyDerivationAlgorithm: rtc.KeyDerivationAlgorithm.kHKDF,
  keyRingSize: 255,
);
final keyProvider = lk.BaseKeyProvider(
  await rtc.frameCryptorFactory.createDefaultKeyProvider(keyProviderOptions),
  keyProviderOptions,
);
final lkRoom = lk.Room(
  roomOptions: lk.RoomOptions(
    encryption: lk.E2EEOptions(keyProvider: keyProvider),
  ),
);

// 2. Join on the Matrix side. Rings the other user in a DM, or notifies the
//    room, if no call was active yet.
final call = await room.joinMatrixRtcCall(intent: MatrixRtcCallIntent.video);

// 3. Feed the keys into LiveKit. For our own key, also switch the encryptor
//    to the new index, otherwise it keeps encrypting with the old key.
call.onNewKey.listen((key) async {
  await keyProvider.setRawKey(
    key.key,
    participantId: key.participantId,
    keyIndex: key.index,
  );
  if (key.participantId == call.ownMembershipId) {
    await lkRoom.e2eeManager?.setKeyIndex(
      key.index,
      participantIdentity: key.participantId,
    );
  }
});

// 4. Connect to the SFU with the credentials from the join.
await lkRoom.connect(call.credentials.url, call.credentials.jwt);

// 5. Publish media.
await lkRoom.localParticipant?.setMicrophoneEnabled(true);
await lkRoom.localParticipant?.setCameraEnabled(
  call.intent == MatrixRtcCallIntent.video,
);
```

`onNewKey` emits our own and the remote keys. `participantId` is `<userId>:<deviceId>`, which is the LiveKit participant identity. Our own keys have `participantId == call.ownMembershipId`. Keys that arrive before you listen are buffered, so listening after the join loses nothing.

The SDK rotates our key when someone leaves. People who join within `makeKeyOnJoinDelay` of the last rotation get the current key instead.

From here on, render `lkRoom.remoteParticipants` and their tracks with the LiveKit widgets, for example `lk.VideoTrackRenderer`.

## Members and hand raising

```dart
call.onChanged.listen((_) => setState(() {})); // Members or raised hands changed
call.onHandRaised.listen((userId) => showToast('$userId raised their hand'));

await call.raiseHand();
await call.lowerHand();
call.userHasHandRaised(userId);
```

A raised hand is a `🖐️` reaction to the user's own member state event. It is carried over when the membership is renewed.

## Leave

```dart
await lkRoom.disconnect();
await call.leave(); // Clears the membership state and disposes the call
```

`call.dispose()` only stops the listeners without leaving, e.g. when the app is closed and the membership should expire on its own.
