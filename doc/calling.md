<!--
SPDX-FileCopyrightText: 2019-Present Famedly GmbH

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Voice and Video Calls

This guide walks through adding voice and video calls to a Flutter app using the MatrixRTC API.
It covers both P2P mesh calls (via `MeshBackend`) and SFU-backed group calls (via `LiveKitBackend`).

> **Note:** The legacy `WebRTCDelegate` / `CallSession` APIs are deprecated. New projects should use the MatrixRTC event stream described here.

## Add dependencies

```yaml
dependencies:
  matrix: <latest-version>
  flutter_webrtc: <latest-version>
```

## Implement WebRTCDelegate

The SDK handles Matrix call signaling. You provide the media layer by implementing `WebRTCDelegate`:

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
    // Reserved for legacy compatibility
  }

  @override
  Future<void> handleNewCall(CallSession session) async {
    // Reserved for legacy compatibility
  }

  @override
  Future<void> handleMissedCall(CallSession session) async {
    // Reserved for legacy compatibility
  }

  @override
  Future<bool> get canHandleNewCall => Future.value(true);
}
```

## Create a group call with MatrixRTC

Attach your delegate to the `Client` via `VoIP`, then create a `GroupCallSession`:

```dart
final delegate = MyCallDelegate();
final voip = VoIP(client, delegate);
final room = client.getRoomById('!roomid:server')!;

// P2P mesh — good for small groups (2–6 participants)
final backend = MeshBackend();

// OR LiveKit SFU — better for large calls
// final backend = LiveKitBackend(
//   liveKitServer: 'https://livekit.example.com',
//   liveKitToken: '...',
// );

final groupCall = GroupCallSession.withAutoGenId(
  room,
  voip,
  backend,
  'm.call',   // application
  'm.room',   // scope
);

// Enter the call (sends member state event, triggers notifications)
await groupCall.enter();
```

## Listen for MatrixRTC events

The `matrixRTCEventStream` delivers typed, pattern-matchable events for everything that happens during a call:

```dart
groupCall.matrixRTCEventStream.stream.listen((event) {
  switch (event) {
    case GroupCallStateChanged(:final state):
      // kEntered | kConnected | kEnded | kIdle
      break;
    case ParticipantsJoinEvent(:final participants):
      for (final p in participants) {
        print('${p.userId} joined');
      }
    case ParticipantsLeftEvent(:final participants):
      for (final p in participants) {
        print('${p.userId} left');
      }
    case GroupCallActiveSpeakerChanged(:final participant):
      // Highlight the active speaker
      break;
    case GroupCallLocalMutedChanged(:final muted, :final kind):
      // Update mute UI
      break;
    case GroupCallLocalScreenshareStateChanged(:final screensharing):
      // Toggle screenshare UI
      break;
    case CallAddedEvent(:final call):
      // A new CallSession was added to the group
      break;
    case CallRemovedEvent(:final call):
      // A CallSession was removed
      break;
    case GroupCallStreamAdded(:final type):
    case GroupCallStreamRemoved(:final type):
      // User media or screenshare stream changed
      break;
    case GroupCallStateError(:final msg, :final err):
      // Handle error
      break;
    default:
      break;
  }
});
```

## Mute, screenshare, and reactions

```dart
// Mute/unmute mic
await backend.setDeviceMuted(groupCall, true, MediaInputKind.audioinput);

// Mute/unmute camera
await backend.setDeviceMuted(groupCall, true, MediaInputKind.videoinput);

// Start/stop screenshare
await backend.setScreensharing(groupCall, true);

// Send a call reaction (hand raise, emoji)
await groupCall.sendReactionEvent(emoji: '🖐️', isEphemeral: true);

// Remove a reaction
await groupCall.removeReactionEvent(eventId: '...');

// Get all reactions of a type
final reactions = await groupCall.getAllReactions(emoji: '🖐️');
```

## Incoming call notifications (MSC4075)

The SDK supports the MSC4075 RTC notification extension for ringing incoming group calls:

```dart
// Send a ring notification when a call starts
await room.sendRtcNotification(
  type: RtcNotificationType.ring,
  userIds: ['@alice:example.com'],
  memberEventId: memberStateEventId,
);

// Check if an incoming event is a ring notification
final notification = event.tryParseRtcNotificationContent();
if (notification != null && notification.shouldNotifyUser(
  event: event,
  currentUserId: client.userID!,
)) {
  // Show incoming call UI / play ringtone
}
```

## Leave a call

```dart
await groupCall.leave();
```

## MatrixRTC event reference

| Event | When it fires |
|---|---|
| `GroupCallStateChanged` | Call state transitions (entered, connected, ended) |
| `ParticipantsJoinEvent` | One or more participants joined |
| `ParticipantsLeftEvent` | One or more participants left |
| `GroupCallActiveSpeakerChanged` | The active speaker changed |
| `GroupCallLocalMutedChanged` | Local mic or camera muted/unmuted |
| `GroupCallLocalScreenshareStateChanged` | Local screenshare started/stopped |
| `CallAddedEvent` | A new CallSession was added to the group |
| `CallRemovedEvent` | A CallSession was removed |
| `CallReplacedEvent` | An existing CallSession was replaced |
| `GroupCallStreamAdded` | A user media or screenshare stream became available |
| `GroupCallStreamRemoved` | A stream was removed |
| `GroupCallStreamReplaced` | A stream was replaced |
| `CallReactionAddedEvent` | A reaction (emoji, hand raise) was added |
| `CallReactionRemovedEvent` | A reaction was removed |
| `GroupCallStateError` | An error occurred |

## Next steps

- For LiveKit backend configuration, see the [VoIP module README](https://github.com/famedly/matrix-dart-sdk/tree/main/lib/src/voip).
- For TURN server configuration, the SDK uses `client.getTurnServer()` automatically when available.
