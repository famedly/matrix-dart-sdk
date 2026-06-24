// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite/model/basic_event_with_sender.dart';
import 'package:matrix/matrix_api_lite/model/presence_content.dart';

class Presence extends BasicEventWithSender {
  PresenceContent presence;

  Presence.fromJson(super.json)
    : presence = PresenceContent.fromJson(
        json['content'] as Map<String, Object?>,
      ),
      super.fromJson();
}
