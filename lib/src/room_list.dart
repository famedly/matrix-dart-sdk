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

  late List<String> _roomsIds;
  late List<String> roomStates;

  RoomList(this.client,
      {this.onUpdate,
      this.onRemove,
      this.onChange,
      this.onPosChanged,
      this.onInsert}) {
    _updateRoomList();

    _onSyncSub =
        client.onSync.stream.where((up) => up.rooms != null).listen(_onSync);
  }
  void _updateRoomList() {
    _roomsIds = rooms.map((e) => e.id).toList();
  }

  bool syncContainRooms(Map<String, SyncRoomUpdate>? update) {
    if (update == null) return false;

    for (final roomId in _roomsIds) {
      if (update.keys.contains(roomId)) return true;
    }
    return false;
  }

  void _onSync(SyncUpdate sync) {
    // first we trigger instertion and deletion

    for (var i = 0; i < client.rooms.length; i++) {
      
    }
    // then when the list is equal, we can check which events where modified
    for (var i = 0; i < client.rooms.length; i++) {
      final room = client.rooms[i];
      if (!_roomsIds.contains(room.id)) {
        onInsert?.call(i);
        _roomsIds.insert(i, room.id);
      } else {
        final oldPos = _roomsIds.indexOf(room.id);
        if (oldPos != i) {
          /// position was updated
          onPosChanged?.call(oldPos, i);
          _roomsIds.removeAt(oldPos);
          _roomsIds.insert(i, room.id);
        } else {
          // item could have been updated
        }
      }
    }

    _updateRoomList();
    onUpdate?.call();
  }

  void dispose() => _onSyncSub?.cancel();

  List<Room> get rooms => client.rooms;
}
