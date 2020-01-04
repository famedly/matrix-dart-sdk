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

/// Represents a new global event like presence or account_data.
class UserUpdate {
  /// Usually 'presence', 'account_data' or whatever.
  final String eventType;

  /// See (Matrix Events)[https://matrix.org/docs/spec/client_server/r0.4.0.html]
  /// for more informations.
  final String type;

  // The json payload of the content of this event.
  final dynamic content;

  UserUpdate({this.eventType, this.type, this.content});
}
