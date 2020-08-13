/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020 Famedly GmbH
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

import '../../matrix_api.dart';

/// This extension adds easy-to-use filters for the sync update, meant to be used on the `client.onSync` stream, e.g.
/// `client.onSync.stream.where((s) => s.hasRoomUpdate)`. Multiple filters can easily be
/// combind with boolean logic: `client.onSync.stream.where((s) => s.hasRoomUpdate || s.hasPresenceUpdate)`
extension SyncUpdateFilters on SyncUpdate {
  /// Returns true if this sync updat has a room update
  /// That means there is account data, if there is a room in one of the `join`, `leave` or `invite` blocks of the sync or if there is a to_device event.
  bool get hasRoomUpdate {
    // if we have an account data change we need to re-render, as `m.direct` might have changed
    if (accountData?.isNotEmpty ?? false) {
      return true;
    }
    // check for a to_device event
    if (toDevice?.isNotEmpty ?? false) {
      return true;
    }
    // return if there are rooms to update
    return (rooms?.join?.isNotEmpty ?? false) ||
        (rooms?.invite?.isNotEmpty ?? false) ||
        (rooms?.leave?.isNotEmpty ?? false);
  }

  /// Returns if this sync update has presence updates
  bool get hasPresenceUpdate => presence != null && presence.isNotEmpty;
}
