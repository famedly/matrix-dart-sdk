// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'basic_event_with_sender.dart';
import 'presence_content.dart';

class Presence extends BasicEventWithSender {
  PresenceContent presence;

  Presence.fromJson(super.json)
    : presence = PresenceContent.fromJson(
        json['content'] as Map<String, Object?>,
      ),
      super.fromJson();
}
