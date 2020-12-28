/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

enum PresenceType { online, offline, unavailable }

class PresenceContent {
  PresenceType presence;
  int lastActiveAgo;
  String statusMsg;
  bool currentlyActive;

  PresenceContent.fromJson(Map<String, dynamic> json) {
    presence = PresenceType.values
        .firstWhere((p) => p.toString().split('.').last == json['presence']);
    lastActiveAgo = json['last_active_ago'];
    statusMsg = json['status_msg'];
    currentlyActive = json['currently_active'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
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
