/* MIT License
* 
* Copyright (C) 2019, 2020, 2021 Famedly GmbH
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

import '../../utils/try_get_map_extension.dart';
import '../basic_event.dart';

extension RoomKeyRequestContentBasicEventExtension on BasicEvent {
  RoomKeyRequestContent get parsedRoomKeyRequestContent =>
      RoomKeyRequestContent.fromJson(content);
}

class RoomKeyRequestContent {
  RequestedKeyInfo? body;
  String action;
  String requestingDeviceId;
  String requestId;

  RoomKeyRequestContent.fromJson(Map<String, dynamic> json)
      : body = ((x) => x != null ? RequestedKeyInfo.fromJson(x) : null)(
            json.tryGet<Map<String, dynamic>>('body')),
        action = json.tryGet<String>('action') ?? '',
        requestingDeviceId = json.tryGet<String>('requesting_device_id') ?? '',
        requestId = json.tryGet<String>('request_id') ?? '';

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (body != null) data['body'] = body!.toJson();
    data['action'] = action;
    data['requesting_device_id'] = requestingDeviceId;
    data['request_id'] = requestId;
    return data;
  }
}

class RequestedKeyInfo {
  String algorithm;
  String roomId;
  String sessionId;
  String senderKey;

  RequestedKeyInfo(
      {required this.algorithm,
      required this.roomId,
      required this.sessionId,
      required this.senderKey});

  RequestedKeyInfo.fromJson(Map<String, dynamic> json)
      : algorithm = json.tryGet('algorithm') ?? '',
        roomId = json.tryGet('room_id') ?? '',
        sessionId = json.tryGet('session_id') ?? '',
        senderKey = json.tryGet('sender_key') ?? '';

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['algorithm'] = algorithm;
    data['room_id'] = roomId;
    data['session_id'] = sessionId;
    data['sender_key'] = senderKey;
    return data;
  }
}
