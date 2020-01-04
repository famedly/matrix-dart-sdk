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

import 'dart:async';
import 'dart:core';
import 'package:famedlysdk/src/account_data.dart';
import 'package:famedlysdk/src/presence.dart';
import 'client.dart';
import 'event.dart';
import 'room.dart';
import 'user.dart';
import 'sync/event_update.dart';
import 'sync/room_update.dart';
import 'sync/user_update.dart';

/// Responsible to store all data persistent and to query objects from the
/// database.
abstract class StoreAPI {
  Client client;

  Future<String> queryPrevBatch();

  /// Will be automatically called when the client is logged in successfully.
  Future<void> storeClient();

  /// Clears all tables from the database.
  Future<void> clear();

  var txn;

  Future<void> transaction(Future<void> queries());

  /// Will be automatically called on every synchronisation. Must be called inside of
  //  /// [transaction].
  Future<void> storePrevBatch(dynamic sync);

  Future<void> storeRoomPrevBatch(Room room);

  /// Stores a RoomUpdate object in the database. Must be called inside of
  /// [transaction].
  Future<void> storeRoomUpdate(RoomUpdate roomUpdate);

  /// Stores an UserUpdate object in the database. Must be called inside of
  /// [transaction].
  Future<void> storeUserEventUpdate(UserUpdate userUpdate);

  /// Stores an EventUpdate object in the database. Must be called inside of
  /// [transaction].
  Future<void> storeEventUpdate(EventUpdate eventUpdate);

  /// Returns a User object by a given Matrix ID and a Room.
  Future<User> getUser({String matrixID, Room room});

  /// Loads all Users in the database to provide a contact list
  /// except users who are in the Room with the ID [exceptRoomID].
  Future<List<User>> loadContacts({String exceptRoomID = ""});

  /// Returns all users of a room by a given [roomID].
  Future<List<User>> loadParticipants(Room room);

  /// Returns a list of events for the given room and sets all participants.
  Future<List<Event>> getEventList(Room room);

  /// Returns all rooms, the client is participating. Excludes left rooms.
  Future<List<Room>> getRoomList({bool onlyLeft = false});

  /// Returns a room without events and participants.
  @deprecated
  Future<Room> getRoomById(String id);

  Future<List<Map<String, dynamic>>> getStatesFromRoomId(String id);

  Future<void> forgetRoom(String roomID);

  Future<void> resetNotificationCount(String roomID);

  /// Searches for the event in the store.
  Future<Event> getEventById(String eventID, Room room);

  Future<Map<String, AccountData>> getAccountData();

  Future<Map<String, Presence>> getPresences();

  Future removeEvent(String eventId);

  Future forgetNotification(String roomID);

  Future addNotification(String roomID, String event_id, int uniqueID);

  Future<List<Map<String, dynamic>>> getNotificationByRoom(String room_id);
}
