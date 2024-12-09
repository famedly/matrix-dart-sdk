/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020, 2021 Famedly GmbH
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

import 'package:matrix/matrix_api_lite.dart';

mixin EventType {
  static const String markedUnread = 'm.marked_unread';
  static const String oldMarkedUnread = 'com.famedly.marked_unread';
}

class MarkedUnread {
  final bool unread;

  const MarkedUnread(this.unread);

  MarkedUnread.fromJson(Map<String, dynamic> json)
      : unread = json.tryGet<bool>('unread') ?? false;

  Map<String, dynamic> toJson() => {'unread': unread};
}
