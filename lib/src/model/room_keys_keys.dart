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

class RoomKeysSingleKey {
  int firstMessageIndex;
  int forwardedCount;
  bool isVerified;
  Map<String, dynamic> sessionData;

  RoomKeysSingleKey(
      {required this.firstMessageIndex,
      required this.forwardedCount,
      required this.isVerified,
      required this.sessionData});

  RoomKeysSingleKey.fromJson(Map<String, dynamic> json)
      : firstMessageIndex = json['first_message_index'],
        forwardedCount = json['forwarded_count'],
        isVerified = json['is_verified'],
        sessionData = json['session_data'];

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
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

  RoomKeysRoom.fromJson(Map<String, dynamic> json)
      : sessions = (json['sessions'] as Map)
            .map((k, v) => MapEntry(k, RoomKeysSingleKey.fromJson(v)));

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['sessions'] = sessions.map((k, v) => MapEntry(k, v.toJson()));
    return data;
  }
}

class RoomKeysUpdateResponse {
  String etag;
  int count;

  RoomKeysUpdateResponse.fromJson(Map<String, dynamic> json)
      : etag = json['etag'], // synapse replies an int but docs say string?
        count = json['count'];

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['etag'] = etag;
    data['count'] = count;
    return data;
  }
}
