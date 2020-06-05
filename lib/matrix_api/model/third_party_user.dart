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

class ThirdPartyUser {
  String userId;
  String protocol;
  Map<String, dynamic> fields;

  ThirdPartyUser.fromJson(Map<String, dynamic> json) {
    userId = json['userid'];
    protocol = json['protocol'];
    fields = Map<String, dynamic>.from(json['fields']);
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['userid'] = userId;
    data['protocol'] = protocol;
    data['fields'] = fields;
    return data;
  }
}
