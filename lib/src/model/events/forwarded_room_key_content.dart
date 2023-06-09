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
import 'room_key_content.dart';

extension ForwardedRoomKeyContentBasicEventExtension on BasicEvent {
  ForwardedRoomKeyContent get parsedForwardedRoomKeyContent =>
      ForwardedRoomKeyContent.fromJson(content);
}

class ForwardedRoomKeyContent extends RoomKeyContent {
  String senderKey;
  String senderClaimedEd25519Key;
  List<String> forwardingCurve25519KeyChain;

  ForwardedRoomKeyContent.fromJson(Map<String, Object?> json)
      : senderKey = json.tryGet('sender_key', TryGet.required) ?? '',
        senderClaimedEd25519Key =
            json.tryGet('sender_claimed_ed25519_key', TryGet.required) ?? '',
        forwardingCurve25519KeyChain = json.tryGetList(
                'forwarding_curve25519_key_chain', TryGet.required) ??
            [],
        super.fromJson(json);

  @override
  Map<String, Object?> toJson() {
    final data = super.toJson();
    data['sender_key'] = senderKey;
    data['sender_claimed_ed25519_key'] = senderClaimedEd25519Key;
    data['forwarding_curve25519_key_chain'] = forwardingCurve25519KeyChain;

    return data;
  }
}
