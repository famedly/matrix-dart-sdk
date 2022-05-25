/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2022 Famedly GmbH
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

import 'dart:async';

import '../matrix.dart';

class RoomList {
  final Client client;
  final void Function()? onUpdate;
  final void Function(int index)? onChange;
  final void Function(int oldPos, int newPos)? onPosChanged;
  final void Function(int index)? onInsert;
  final void Function(int index)? onRemove;

  StreamSubscription<SyncUpdate>? _onSyncSub;

  late List<Room> _roomsIds;
  late List<String> roomStates;

  RoomList(this.client,
      {this.onUpdate,
      this.onRemove,
      this.onChange,
      this.onPosChanged,
      this.onInsert})
      : _roomsIds = client.rooms {
    _onSyncSub =
        client.onSync.stream.where((up) => up.rooms != null).listen(_onSync);
  }

  bool syncContainRooms(SyncUpdate update, Room room) {
    if (update.rooms == null) return false;

    if ((update.rooms?.invite?.keys.contains(room.id) ?? false) ||
        (update.rooms?.join?.keys.contains(room.id) ?? false) ||
        (update.rooms?.leave?.keys.contains(room.id) ?? false)) return true;

    return false;
  }

  void _onSync(SyncUpdate sync) {
    // first we trigger instertion and deletion
    final newRooms = client.rooms.toList();

    for (var i = 0; i < rooms.length; i++) {
      final room = newRooms[i];
      if (!_roomsIds.contains(room)) {
        _roomsIds.insert(i, room);
        onInsert?.call(i);
      }
    }

    for (var i = 0; i < _roomsIds.length; i++) {
      if (!newRooms.contains(_roomsIds[i])) {
        _roomsIds.removeAt(i);
        onRemove?.call(i);
        i--;
      }
    }

    // then when the list is equal, we can check which events where modified
    for (var i = 0; i < newRooms.length; i++) {
      final room = newRooms[i];
      {
        final newPos = newRooms.indexOf(room);
        if (newPos != i) {
          /// position was updated
          _roomsIds.removeAt(i);
          _roomsIds.insert(newPos, room);

          onPosChanged?.call(i, newPos);

          // If we added the new element later, we need to stay at the same place
          if (i < newPos) {
            i--;
          }
        } else {
          // item could have been updated
          if (syncContainRooms(sync, room)) {
            onChange?.call(i);
          }
        }
      }
    }

    onUpdate?.call();
  }

  void dispose() => _onSyncSub?.cancel();

  List<Room> get rooms => _roomsIds;
}
