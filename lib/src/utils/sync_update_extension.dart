// SPDX-FileCopyrightText: 2019-Present, 2020, 2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';

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
  bool get hasPresenceUpdate => presence?.isNotEmpty ?? false;
}
