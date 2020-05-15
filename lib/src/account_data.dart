/*
 * Copyright (c) 2019 Zender & Kurtz GbR.
 *
 * Authors:
 *   Christian Pauly <krille@famedly.com>
 *   Marcel Radzio <mtrnord@famedly.com>
 *
 * This file is part of famedlysdk.
 *
 * famedlysdk is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * famedlysdk is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with famedlysdk.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'package:famedlysdk/famedlysdk.dart';
import './database/database.dart' show DbAccountData;

/// The global private data created by this user.
class AccountData {
  /// The json payload of the content. The content highly depends on the type.
  final Map<String, dynamic> content;

  /// The type String of this event. For example 'm.room.message'.
  final String typeKey;

  AccountData({this.content, this.typeKey});

  /// Get a State event from a table row or from the event stream.
  factory AccountData.fromJson(Map<String, dynamic> jsonPayload) {
    final content = Event.getMapFromPayload(jsonPayload['content']);
    return AccountData(content: content, typeKey: jsonPayload['type']);
  }

  /// Get account data from DbAccountData
  factory AccountData.fromDb(DbAccountData dbEntry) {
    final content = Event.getMapFromPayload(dbEntry.content);
    return AccountData(content: content, typeKey: dbEntry.type);
  }
}
