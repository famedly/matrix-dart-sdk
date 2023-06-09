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

import 'package:matrix_api_lite/matrix_api_lite.dart';

class RoomKeysSingleKey {
  int firstMessageIndex;
  int forwardedCount;
  bool isVerified;
  Map<String, Object?> sessionData;

  RoomKeysSingleKey(
      {required this.firstMessageIndex,
      required this.forwardedCount,
      required this.isVerified,
      required this.sessionData});

  RoomKeysSingleKey.fromJson(Map<String, Object?> json)
      : firstMessageIndex = json['first_message_index'] as int,
        forwardedCount = json['forwarded_count'] as int,
        isVerified = json['is_verified'] as bool,
        sessionData = json['session_data'] as Map<String, Object?>;

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    data['first_message_index'] = firstMessageIndex;
    data['forwarded_count'] = forwardedCount;
    data['is_verified'] = isVerified;
    data['session_data'] = sessionData;
    return data;
  }
}

class RoomKeysRoom {
  Map<String, RoomKeysSingleKey> sessions;

  RoomKeysRoom({required this.sessions});

  RoomKeysRoom.fromJson(Map<String, Object?> json)
      : sessions = (json['sessions'] as Map<String, Object?>).map((k, v) =>
            MapEntry(k, RoomKeysSingleKey.fromJson(v as Map<String, Object?>)));

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    data['sessions'] = sessions.map((k, v) => MapEntry(k, v.toJson()));
    return data;
  }
}

class RoomKeysUpdateResponse {
  String etag;
  int count;

  RoomKeysUpdateResponse.fromJson(Map<String, Object?> json)
      : etag = json.tryGet<String>('etag') ??
            '', // synapse replies an int but docs say string?
        count = json.tryGet<int>('count') ?? 0;

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    data['etag'] = etag;
    data['count'] = count;
    return data;
  }
}
