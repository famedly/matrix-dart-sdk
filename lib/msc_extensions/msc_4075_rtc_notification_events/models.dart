/* MIT License
* 
* Copyright (C) 2019, 2020, 2021, 2022 Famedly GmbH
* 
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
* 
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
* 
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

/// MSC4075: RTC notification events
/// https://github.com/matrix-org/matrix-spec-proposals/blob/toger5/matrixrtc-call-ringing/proposals/4075-rtc-notification-event.md
library;

/// Event type constant for RTC notifications
class RTCNotificationEventTypes {
  static const String rtcNotification = 'org.matrix.msc4075.rtc.notification';
}

/// Content for an RTC notification event
class RTCNotificationContent {
  /// The unique ID of the call being notified about
  final String callId;

  /// The room ID where the call is happening
  final String roomId;

  /// The type of call: 'voice' or 'video'
  final String callType;

  /// The type of notification: 'ring' (full ringing UI), 'notify' (silent notification)
  final String notifyType;

  /// When this notification was sent (milliseconds since epoch)
  final int timestamp;

  RTCNotificationContent({
    required this.callId,
    required this.roomId,
    required this.callType,
    required this.notifyType,
    required this.timestamp,
  });

  factory RTCNotificationContent.fromJson(Map<String, dynamic> json) {
    return RTCNotificationContent(
      callId: json['call_id'] as String,
      roomId: json['room_id'] as String,
      callType: json['call_type'] as String,
      notifyType: json['notify_type'] as String,
      timestamp: json['timestamp'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'call_id': callId,
      'room_id': roomId,
      'call_type': callType,
      'notify_type': notifyType,
      'timestamp': timestamp,
    };
  }
}
