<!--
SPDX-FileCopyrightText: 2019-Present Famedly GmbH

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Voice and Video Calls

This guide walks through adding 1:1 voice and video calls to a Flutter app using `flutter_webrtc`. For group calls and LiveKit integration, see the [VoIP module README](https://github.com/famedly/matrix-dart-sdk/tree/main/lib/src/voip).

## Add dependencies

```yaml
dependencies:
  matrix: <latest-version>
  flutter_webrtc: <latest-version>
```

## Implement WebRTCDelegate

The SDK handles Matrix call signaling (invite, answer, hangup). You provide the media layer by implementing `WebRTCDelegate`:

```dart
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:matrix/matrix.dart';

class MyCallDelegate implements WebRTCDelegate {
  @override
  MediaDevices get mediaDevices => webrtc.navigator.mediaDevices;

  @override
  Future<RTCPeerConnection> createPeerConnection(
    Map<String, dynamic> configuration,
    [Map<String, dynamic> constraints = const {}],
  ) =>
      webrtc.createPeerConnection(configuration, constraints);

  @override
  VideoRenderer createRenderer() => webrtc.RTCVideoRenderer();

  @override
  Future<void> playRingtone() async {
    // Start ringing
  }

  @override
  Future<void> stopRingtone() async {
    // Stop ringing
  }

  @override
  Future<void> registerListeners(CallSession session) async {
    session.onCallStateChanged.stream.listen((state) {
      // React to call state transitions
    });
  }

  @override
  Future<void> handleNewCall(CallSession session) async {
    // Show incoming or outgoing call UI
  }

  @override
  Future<void> handleMissedCall(CallSession session) async {
    // Notify the user about a missed call
  }

  @override
  Future<bool> get canHandleNewCall => Future.value(true);
}
```

## Set up VoIP on the Client

Attach your delegate to the `Client` via the `VoIP` class. The SDK then handles all Matrix call events automatically:

```dart
final delegate = MyCallDelegate();
final voip = VoIP(client, delegate);
```

## Make an outgoing call

```dart
final call = await voip.inviteToCall(
  room,
  CallType.kVideo,  // or CallType.kVoice for audio only
  userId: '@user:server.com',
);

call.onCallStateChanged.stream.listen((state) {
  // kRinging → kConnecting → kConnected → kEnded
});

call.answer();   // answer incoming
call.hangup();   // end the call
call.reject();   // reject incoming
```

## Receive an incoming call

The SDK fires `delegate.handleNewCall()` when a call arrives. Check the direction:

```dart
@override
Future<void> handleNewCall(CallSession session) async {
  switch (session.direction) {
    case CallDirection.kIncoming:
      // Show incoming call screen with answer/reject buttons
      break;
    case CallDirection.kOutgoing:
      // Show outgoing call screen with hangup button
      break;
  }
}
```

## Call state reference

| State | Meaning |
|---|---|
| `kFledgling` | Call object created |
| `kWaitLocalMedia` | Requesting mic/camera |
| `kCreateOffer` | Preparing SDP offer |
| `kInviteSent` / `kRinging` | Call is ringing — play ringtone here |
| `kConnecting` | Peer connection establishing |
| `kConnected` | Media flowing — stop ringtone |
| `kEnding` / `kEnded` | Call finished |

## Next steps

- For group calls and LiveKit, see the [VoIP module README](https://github.com/famedly/matrix-dart-sdk/tree/main/lib/src/voip).
- For TURN server configuration, the SDK uses `client.getTurnServer()` automatically when available.
