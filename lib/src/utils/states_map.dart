/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020, 2021 Famedly GmbH
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

import '../../famedlysdk.dart';

/// Matrix room states are addressed by a tuple of the [type] and an
/// optional [stateKey].
class StatesMap {
  Map<String, Map<String, Event>> states = {};

  /// Returns either the [Event] or a map of state_keys to [Event] objects.
  /// If you just enter a MatrixID, it will try to return the corresponding m.room.member event.
  dynamic operator [](String key) {
    //print("[Warning] This method will be depracated in the future!");
    if (key == null) return null;
    if (key.startsWith('@') && key.contains(':')) {
      if (!states.containsKey(EventTypes.RoomMember)) {
        states[EventTypes.RoomMember] = {};
      }
      return states[EventTypes.RoomMember][key];
    }
    if (!states.containsKey(key)) states[key] = {};
    if (states[key][''] is Event) {
      return states[key][''];
    } else if (states[key].isEmpty) {
      return null;
    } else {
      return states[key];
    }
  }

  void operator []=(String key, Event val) {
    //print("[Warning] This method will be depracated in the future!");
    if (key.startsWith('@') && key.contains(':')) {
      if (!states.containsKey(EventTypes.RoomMember)) {
        states[EventTypes.RoomMember] = {};
      }
      states[EventTypes.RoomMember][key] = val;
    }
    if (!states.containsKey(key)) states[key] = {};
    states[key][val.stateKey ?? ''] = val;
  }

  bool containsKey(String key) => states.containsKey(key);

  void forEach(f) => states.forEach(f);
}
