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

class Tag {
  double order;

  Tag.fromJson(Map<String, dynamic> json) {
    order = double.tryParse(json['order'].toString());
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (order != null) {
      data['order'] = order;
    }
    return data;
  }
}

abstract class TagType {
  static const String Favourite = 'm.favourite';
  static const String LowPriority = 'm.lowpriority';
  static const String ServerNotice = 'm.server_notice';
  static bool isValid(String tag) => tag.startsWith('m.')
      ? [Favourite, LowPriority, ServerNotice].contains(tag)
      : true;
}
