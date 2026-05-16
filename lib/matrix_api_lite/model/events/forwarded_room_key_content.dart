// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite/model/basic_event.dart';
import 'package:matrix/matrix_api_lite/model/events/room_key_content.dart';
import 'package:matrix/matrix_api_lite/utils/try_get_map_extension.dart';

extension ForwardedRoomKeyContentBasicEventExtension on BasicEvent {
  ForwardedRoomKeyContent get parsedForwardedRoomKeyContent =>
      ForwardedRoomKeyContent.fromJson(content);
}

class ForwardedRoomKeyContent extends RoomKeyContent {
  String senderKey;
  String senderClaimedEd25519Key;
  List<String> forwardingCurve25519KeyChain;

  ForwardedRoomKeyContent.fromJson(super.json)
      : senderKey = json.tryGet('sender_key', TryGet.required) ?? '',
        senderClaimedEd25519Key =
            json.tryGet('sender_claimed_ed25519_key', TryGet.required) ?? '',
        forwardingCurve25519KeyChain = json.tryGetList(
              'forwarding_curve25519_key_chain',
              TryGet.required,
            ) ??
            [],
        super.fromJson();

  @override
  Map<String, Object?> toJson() {
    final data = super.toJson();
    data['sender_key'] = senderKey;
    data['sender_claimed_ed25519_key'] = senderClaimedEd25519Key;
    data['forwarding_curve25519_key_chain'] = forwardingCurve25519KeyChain;

    return data;
  }
}
