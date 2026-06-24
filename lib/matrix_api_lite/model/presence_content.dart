// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite.dart';

class PresenceContent {
  PresenceType presence;
  int? lastActiveAgo;
  String? statusMsg;
  bool? currentlyActive;

  PresenceContent.fromJson(Map<String, Object?> json)
    : presence = PresenceType.values.firstWhere(
        (p) => p.toString().split('.').last == json['presence'],
        orElse: () => PresenceType.offline,
      ),
      lastActiveAgo = json.tryGet<int>('last_active_ago'),
      statusMsg = json.tryGet<String>('status_msg'),
      currentlyActive = json.tryGet<bool>('currently_active');

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    data['presence'] = presence.toString().split('.').last;
    if (lastActiveAgo != null) {
      data['last_active_ago'] = lastActiveAgo;
    }
    if (statusMsg != null) {
      data['status_msg'] = statusMsg;
    }
    if (currentlyActive != null) {
      data['currently_active'] = currentlyActive;
    }
    return data;
  }
}
