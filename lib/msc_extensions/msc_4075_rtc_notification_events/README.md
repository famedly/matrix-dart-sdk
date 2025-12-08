# MSC 4075: RTC Notification Events

This extension implements [MSC 4075](https://github.com/matrix-org/matrix-spec-proposals/blob/toger5/matrixrtc-call-ringing/proposals/4075-rtc-notification-event.md), which adds lightweight notification events for MatrixRTC sessions.

The event type used by this extension is:
- `org.matrix.msc4075.rtc.notification`

## Features

- Send RTC notification events when initiating calls
- Receive and handle incoming RTC notification events
- Configurable notification types ('ring' or 'notify')
- Push rules for RTC notifications

## Usage

### Sending RTC Notification Events

Use `sendRTCNotificationEvent` to notify participants about an incoming call:

```dart
import 'package:matrix/msc_extensions/msc_4075_rtc_notification_events/msc_4075_rtc_notification_events.dart';

await client.sendRTCNotificationEvent(
  roomId: '!room:example.org',
  callId: 'call_123',
  callType: 'video', // or 'voice'
  notifyType: 'ring', // or 'notify' for silent notifications
);
```

### Listening for RTC Notification Events

Set up a listener to receive incoming RTC notifications:

```dart
import 'package:matrix/msc_extensions/msc_4075_rtc_notification_events/msc_4075_rtc_notification_events.dart';

// Set up the listener (call once during client initialization)
client.setupRTCNotificationListener();

// Subscribe to incoming notifications
client.onRTCNotification.listen((notification) {
  print('Incoming ${notification.callType} call in room ${notification.roomId}');
  print('Call ID: ${notification.callId}');
  print('Notify type: ${notification.notifyType}');
  
  if (notification.notifyType == 'ring') {
    // Show full ringing UI
  } else {
    // Show silent/banner notification
  }
});
```

### Enabling Push Notifications

Enable push notifications for RTC notification events with a "ring" sound:

```dart
await client.enableRTCNotificationPushRule();
```

### Disabling Push Notifications

Disable push notifications for RTC notification events:

```dart
await client.disableRTCNotificationPushRule();
```
