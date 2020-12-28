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

class WellKnownInformations {
  MHomeserver mHomeserver;
  MHomeserver mIdentityServer;
  Map<String, dynamic> content;

  WellKnownInformations.fromJson(Map<String, dynamic> json) {
    content = json;
    mHomeserver = json['m.homeserver'] != null
        ? MHomeserver.fromJson(json['m.homeserver'])
        : null;
    mIdentityServer = json['m.identity_server'] != null
        ? MHomeserver.fromJson(json['m.identity_server'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final data = content;
    data['m.homeserver'] = mHomeserver.toJson();
    data['m.identity_server'] = mIdentityServer.toJson();
    return data;
  }
}

class MHomeserver {
  String baseUrl;

  MHomeserver.fromJson(Map<String, dynamic> json) {
    baseUrl = json['base_url'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['base_url'] = baseUrl;
    return data;
  }
}
