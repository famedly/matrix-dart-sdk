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
import 'dart:convert';
import 'dart:core';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'Client.dart';
import 'Connection.dart';
import 'Event.dart';
import 'Room.dart';
import 'User.dart';
import 'sync/EventUpdate.dart';
import 'sync/RoomUpdate.dart';
import 'sync/UserUpdate.dart';

/// Responsible to store all data persistent and to query objects from the
/// database.
class Store {
  final Client client;

  Store(this.client) {
    _init();
  }

  Database _db;

  /// SQLite database for all persistent data. It is recommended to extend this
  /// SDK instead of writing direct queries to the database.
  Database get db => _db;

  _init() async {
    var databasePath = await getDatabasesPath();
    String path = p.join(databasePath, "FluffyMatrix.db");
    _db = await openDatabase(path, version: 9,
        onCreate: (Database db, int version) async {
      await createTables(db);
    }, onUpgrade: (Database db, int oldVersion, int newVersion) async {
      if (client.debug)
        print(
            "[Store] Migrate databse from version $oldVersion to $newVersion");
      if (oldVersion != newVersion) {
        await schemes.forEach((String name, String scheme) async {
          await db.execute("DROP TABLE IF EXISTS ?", [name]);
        });
        db.rawUpdate("UPDATE Clients SET prev_batch='' WHERE client=?",
            [client.clientName]);
        await createTables(db);
      }
    });

    await _db.rawUpdate("UPDATE Events SET status=-1 WHERE status=0");

    List<Map> list = await _db
        .rawQuery("SELECT * FROM Clients WHERE client=?", [client.clientName]);
    if (list.length == 1) {
      var clientList = list[0];
      client.connection.connect(
        newToken: clientList["token"],
        newHomeserver: clientList["homeserver"],
        newUserID: clientList["matrix_id"],
        newDeviceID: clientList["device_id"],
        newDeviceName: clientList["device_name"],
        newLazyLoadMembers: clientList["lazy_load_members"] == 1,
        newMatrixVersions: clientList["matrix_versions"].toString().split(","),
        newPrevBatch: clientList["prev_batch"].toString().isEmpty
            ? null
            : clientList["prev_batch"],
      );
      if (client.debug)
        print("[Store] Restore client credentials of ${client.userID}");
    } else
      client.connection.onLoginStateChanged.add(LoginState.loggedOut);
  }

  Future<void> createTables(Database db) async {
    await schemes.forEach((String name, String scheme) async {
      await db.execute(scheme);
    });
  }

  Future<String> queryPrevBatch() async {
    List<Map> list = await txn.rawQuery(
        "SELECT prev_batch FROM Clients WHERE client=?", [client.clientName]);
    return list[0]["prev_batch"];
  }

  /// Will be automatically called when the client is logged in successfully.
  Future<void> storeClient() async {
    await _db
        .rawInsert('INSERT OR IGNORE INTO Clients VALUES(?,?,?,?,?,?,?,?,?)', [
      client.clientName,
      client.accessToken,
      client.homeserver,
      client.userID,
      client.deviceID,
      client.deviceName,
      client.prevBatch,
      client.matrixVersions.join(","),
      client.lazyLoadMembers,
    ]);
    return;
  }

  /// Clears all tables from the database.
  Future<void> clear() async {
    await _db
        .rawDelete("DELETE FROM Clients WHERE client=?", [client.clientName]);
    await schemes.forEach((String name, String scheme) async {
      if (name != "Clients") await db.rawDelete("DELETE FROM $name", [name]);
    });
    return;
  }

  Transaction txn;

  Future<void> transaction(Future<void> queries()) async {
    return client.store.db.transaction((txnObj) async {
      txn = txnObj;
      await queries();
    });
  }

  /// Will be automatically called on every synchronisation. Must be called inside of
  //  /// [transaction].
  Future<void> storePrevBatch(dynamic sync) {
    txn.rawUpdate("UPDATE Clients SET prev_batch=? WHERE client=?",
        [client.prevBatch, client.clientName]);
    return null;
  }

  Future<void> storeRoomPrevBatch(Room room) async {
    await _db.rawUpdate(
        "UPDATE Rooms SET prev_batch=? WHERE id=?", [room.prev_batch, room.id]);
    return null;
  }

  /// Stores a RoomUpdate object in the database. Must be called inside of
  /// [transaction].
  Future<void> storeRoomUpdate(RoomUpdate roomUpdate) {
    // Insert the chat into the database if not exists
    txn.rawInsert(
        "INSERT OR IGNORE INTO Rooms " +
            "VALUES(?, ?, '', 0, 0, '', '', '', 0, '', '', '', '', '', '', '', '', 0, 50, 50, 0, 50, 50, 0, 50, 100, 50, 50, 50, 100) ",
        [roomUpdate.id, roomUpdate.membership.toString().split('.').last]);

    // Update the notification counts and the limited timeline boolean
    txn.rawUpdate(
        "UPDATE Rooms SET highlight_count=?, notification_count=?, membership=? WHERE id=? ",
        [
          roomUpdate.highlight_count,
          roomUpdate.notification_count,
          roomUpdate.membership.toString().split('.').last,
          roomUpdate.id
        ]);

    // Is the timeline limited? Then all previous messages should be
    // removed from the database!
    if (roomUpdate.limitedTimeline) {
      txn.rawDelete("DELETE FROM Events WHERE chat_id=?", [roomUpdate.id]);
      txn.rawUpdate("UPDATE Rooms SET prev_batch=? WHERE id=?",
          [roomUpdate.prev_batch, roomUpdate.id]);
    }
    return null;
  }

  /// Stores an UserUpdate object in the database. Must be called inside of
  /// [transaction].
  Future<void> storeUserEventUpdate(UserUpdate userUpdate) {
    switch (userUpdate.eventType) {
      case "m.direct":
        if (userUpdate.content["content"] is Map<String, dynamic>) {
          final Map<String, dynamic> directMap = userUpdate.content["content"];
          directMap.forEach((String key, dynamic value) {
            if (value is List<dynamic> && value.length > 0)
              for (int i = 0; i < value.length; i++) {
                txn.rawUpdate(
                    "UPDATE Rooms SET direct_chat_matrix_id=? WHERE id=?",
                    [key, value[i]]);
              }
          });
        }
        break;
    }
    return null;
  }

  /// Stores an EventUpdate object in the database. Must be called inside of
  /// [transaction].
  Future<void> storeEventUpdate(EventUpdate eventUpdate) {
    Map<String, dynamic> eventContent = eventUpdate.content;
    String type = eventUpdate.type;
    String chat_id = eventUpdate.roomID;

    if (type == "timeline" || type == "history") {
      // calculate the status
      num status = 2;
      if (eventContent["status"] is num) status = eventContent["status"];

      // Make unsigned part of the content
      if (eventContent.containsKey("unsigned")) {
        Map<String, dynamic> newContent = {
          "unsigned": eventContent["unsigned"]
        };
        eventContent["content"].forEach((key, val) => newContent[key] = val);
        eventContent["content"] = newContent;
      }

      // Get the state_key for m.room.member events
      String state_key = "";
      if (eventContent["state_key"] is String) {
        state_key = eventContent["state_key"];
      }

      // Save the event in the database
      if ((status == 1 || status == -1) &&
          eventContent["unsigned"] is Map<String, dynamic> &&
          eventContent["unsigned"]["transaction_id"] is String)
        txn.rawUpdate("UPDATE Events SET status=?, id=? WHERE id=?", [
          status,
          eventContent["event_id"],
          eventContent["unsigned"]["transaction_id"]
        ]);
      else
        txn.rawInsert(
            "INSERT OR REPLACE INTO Events VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)", [
          eventContent["event_id"],
          chat_id,
          eventContent["origin_server_ts"],
          eventContent["sender"],
          state_key,
          eventContent["content"]["body"],
          eventContent["type"],
          json.encode(eventContent["content"]),
          status
        ]);

      // Is there a transaction id? Then delete the event with this id.
      if (status != -1 &&
          eventUpdate.content.containsKey("unsigned") &&
          eventUpdate.content["unsigned"]["transaction_id"] is String)
        txn.rawDelete("DELETE FROM Events WHERE id=?",
            [eventUpdate.content["unsigned"]["transaction_id"]]);
    }

    if (type == "history") return null;

    switch (eventUpdate.eventType) {
      case "m.receipt":
        if (eventContent["user"] == client.userID) {
          txn.rawUpdate("UPDATE Rooms SET unread=? WHERE id=?",
              [eventContent["ts"], chat_id]);
        } else {
          // Mark all previous received messages as seen
          txn.rawUpdate(
              "UPDATE Events SET status=3 WHERE origin_server_ts<=? AND chat_id=? AND status=2",
              [eventContent["ts"], chat_id]);
        }
        break;
      // This event means, that the name of a room has been changed, so
      // it has to be changed in the database.
      case "m.room.name":
        txn.rawUpdate("UPDATE Rooms SET topic=? WHERE id=?",
            [eventContent["content"]["name"], chat_id]);
        break;
      // This event means, that the topic of a room has been changed, so
      // it has to be changed in the database
      case "m.room.topic":
        txn.rawUpdate("UPDATE Rooms SET description=? WHERE id=?",
            [eventContent["content"]["topic"], chat_id]);
        break;
      // This event means, that the topic of a room has been changed, so
      // it has to be changed in the database
      case "m.room.history_visibility":
        txn.rawUpdate("UPDATE Rooms SET history_visibility=? WHERE id=?",
            [eventContent["content"]["history_visibility"], chat_id]);
        break;
      // This event means, that the topic of a room has been changed, so
      // it has to be changed in the database
      case "m.room.redaction":
        txn.rawDelete(
            "DELETE FROM Events WHERE id=?", [eventContent["redacts"]]);
        break;
      // This event means, that the topic of a room has been changed, so
      // it has to be changed in the database
      case "m.room.guest_access":
        txn.rawUpdate("UPDATE Rooms SET guest_access=? WHERE id=?",
            [eventContent["content"]["guest_access"], chat_id]);
        break;
      // This event means, that the canonical alias of a room has been changed, so
      // it has to be changed in the database
      case "m.room.canonical_alias":
        txn.rawUpdate("UPDATE Rooms SET canonical_alias=? WHERE id=?",
            [eventContent["content"]["alias"], chat_id]);
        break;
      // This event means, that the topic of a room has been changed, so
      // it has to be changed in the database
      case "m.room.join_rules":
        txn.rawUpdate("UPDATE Rooms SET join_rules=? WHERE id=?",
            [eventContent["content"]["join_rule"], chat_id]);
        break;
      // This event means, that the avatar of a room has been changed, so
      // it has to be changed in the database
      case "m.room.avatar":
        txn.rawUpdate("UPDATE Rooms SET avatar_url=? WHERE id=?",
            [eventContent["content"]["url"], chat_id]);
        break;
      // This event means, that the aliases of a room has been changed, so
      // it has to be changed in the database
      case "m.fully_read":
        txn.rawUpdate("UPDATE Rooms SET fully_read=? WHERE id=?",
            [eventContent["content"]["event_id"], chat_id]);
        break;
      // This event means, that someone joined the room, has left the room
      // or has changed his nickname
      case "m.room.member":
        String membership = eventContent["content"]["membership"];
        String state_key = eventContent["state_key"];
        String insertDisplayname = "";
        String insertAvatarUrl = "";
        if (eventContent["content"]["displayname"] is String) {
          insertDisplayname = eventContent["content"]["displayname"];
        }
        if (eventContent["content"]["avatar_url"] is String) {
          insertAvatarUrl = eventContent["content"]["avatar_url"];
        }

        // Update membership table
        txn.rawInsert("INSERT OR IGNORE INTO Users VALUES(?,?,?,?,?,0)", [
          chat_id,
          state_key,
          insertDisplayname,
          insertAvatarUrl,
          membership
        ]);
        String queryStr = "UPDATE Users SET membership=?";
        List<String> queryArgs = [membership];

        if (eventContent["content"]["displayname"] is String) {
          queryStr += " , displayname=?";
          queryArgs.add(eventContent["content"]["displayname"]);
        }
        if (eventContent["content"]["avatar_url"] is String) {
          queryStr += " , avatar_url=?";
          queryArgs.add(eventContent["content"]["avatar_url"]);
        }

        queryStr += " WHERE matrix_id=? AND chat_id=?";
        queryArgs.add(state_key);
        queryArgs.add(chat_id);
        txn.rawUpdate(queryStr, queryArgs);
        break;
      // This event changes the permissions of the users and the power levels
      case "m.room.power_levels":
        String query = "UPDATE Rooms SET ";
        if (eventContent["content"]["ban"] is num)
          query += ", power_ban=" + eventContent["content"]["ban"].toString();
        if (eventContent["content"]["events_default"] is num)
          query += ", power_events_default=" +
              eventContent["content"]["events_default"].toString();
        if (eventContent["content"]["state_default"] is num)
          query += ", power_state_default=" +
              eventContent["content"]["state_default"].toString();
        if (eventContent["content"]["redact"] is num)
          query +=
              ", power_redact=" + eventContent["content"]["redact"].toString();
        if (eventContent["content"]["invite"] is num)
          query +=
              ", power_invite=" + eventContent["content"]["invite"].toString();
        if (eventContent["content"]["kick"] is num)
          query += ", power_kick=" + eventContent["content"]["kick"].toString();
        if (eventContent["content"]["user_default"] is num)
          query += ", power_user_default=" +
              eventContent["content"]["user_default"].toString();
        if (eventContent["content"]["events"] is Map<String, dynamic>) {
          if (eventContent["content"]["events"]["m.room.avatar"] is num)
            query += ", power_event_avatar=" +
                eventContent["content"]["events"]["m.room.avatar"].toString();
          if (eventContent["content"]["events"]["m.room.history_visibility"]
              is num)
            query += ", power_event_history_visibility=" +
                eventContent["content"]["events"]["m.room.history_visibility"]
                    .toString();
          if (eventContent["content"]["events"]["m.room.canonical_alias"]
              is num)
            query += ", power_event_canonical_alias=" +
                eventContent["content"]["events"]["m.room.canonical_alias"]
                    .toString();
          if (eventContent["content"]["events"]["m.room.aliases"] is num)
            query += ", power_event_aliases=" +
                eventContent["content"]["events"]["m.room.aliases"].toString();
          if (eventContent["content"]["events"]["m.room.name"] is num)
            query += ", power_event_name=" +
                eventContent["content"]["events"]["m.room.name"].toString();
          if (eventContent["content"]["events"]["m.room.power_levels"] is num)
            query += ", power_event_power_levels=" +
                eventContent["content"]["events"]["m.room.power_levels"]
                    .toString();
        }
        if (query != "UPDATE Rooms SET ") {
          query = query.replaceFirst(",", "");
          txn.rawUpdate(query + " WHERE id=?", [chat_id]);
        }

        // Set the users power levels:
        if (eventContent["content"]["users"] is Map<String, dynamic>) {
          eventContent["content"]["users"]
              .forEach((String user, dynamic value) async {
            num power_level = eventContent["content"]["users"][user];
            txn.rawUpdate(
                "UPDATE Users SET power_level=? WHERE matrix_id=? AND chat_id=?",
                [power_level, user, chat_id]);
            txn.rawInsert(
                "INSERT OR IGNORE INTO Users VALUES(?, ?, '', '', ?, ?)",
                [chat_id, user, "unknown", power_level]);
          });
        }
        break;
    }
    return null;
  }

  /// Returns a User object by a given Matrix ID and a Room.
  Future<User> getUser({String matrixID, Room room}) async {
    List<Map<String, dynamic>> res = await db.rawQuery(
        "SELECT * FROM Users WHERE matrix_id=? AND chat_id=?",
        [matrixID, room.id]);
    if (res.length != 1) return null;
    return User.fromJson(res[0], room);
  }

  /// Loads all Users in the database to provide a contact list
  /// except users who are in the Room with the ID [exceptRoomID].
  Future<List<User>> loadContacts({String exceptRoomID = ""}) async {
    List<Map<String, dynamic>> res = await db.rawQuery(
        "SELECT * FROM Users WHERE matrix_id!=? AND chat_id!=? GROUP BY matrix_id ORDER BY displayname",
        [client.userID, exceptRoomID]);
    List<User> userList = [];
    for (int i = 0; i < res.length; i++)
      userList.add(User.fromJson(res[i], Room(id: "", client: client)));
    return userList;
  }

  /// Returns all users of a room by a given [roomID].
  Future<List<User>> loadParticipants(Room room) async {
    List<Map<String, dynamic>> res = await db.rawQuery(
        "SELECT * " +
            " FROM Users " +
            " WHERE chat_id=? " +
            " AND membership='join'",
        [room.id]);

    List<User> participants = [];

    for (num i = 0; i < res.length; i++) {
      participants.add(User.fromJson(res[i], room));
    }

    return participants;
  }

  /// Returns a list of events for the given room and sets all participants.
  Future<List<Event>> getEventList(Room room) async {
    List<Map<String, dynamic>> memberRes = await db.rawQuery(
        "SELECT * " + " FROM Users " + " WHERE Users.chat_id=?", [room.id]);
    Map<String, User> userMap = {};
    for (num i = 0; i < memberRes.length; i++)
      userMap[memberRes[i]["matrix_id"]] = User.fromJson(memberRes[i], room);

    List<Map<String, dynamic>> eventRes = await db.rawQuery(
        "SELECT * " +
            " FROM Events events " +
            " WHERE events.chat_id=?" +
            " GROUP BY events.id " +
            " ORDER BY origin_server_ts DESC",
        [room.id]);

    List<Event> eventList = [];

    for (num i = 0; i < eventRes.length; i++)
      eventList.add(Event.fromJson(eventRes[i], room,
          senderUser: userMap[eventRes[i]["sender"]],
          stateKeyUser: userMap[eventRes[i]["state_key"]]));

    return eventList;
  }

  /// Returns all rooms, the client is participating. Excludes left rooms.
  Future<List<Room>> getRoomList(
      {bool onlyLeft = false,
      bool onlyDirect = false,
      bool onlyGroups = false}) async {
    if (onlyDirect && onlyGroups) return [];
    List<Map<String, dynamic>> res = await db.rawQuery(
        "SELECT rooms.*, events.origin_server_ts, events.content_json, events.type, events.sender, events.status, events.state_key " +
            " FROM Rooms rooms LEFT JOIN Events events " +
            " ON rooms.id=events.chat_id " +
            " WHERE rooms.membership" +
            (onlyLeft ? "=" : "!=") +
            "'leave' " +
            (onlyDirect ? " AND rooms.direct_chat_matrix_id!= '' " : "") +
            (onlyGroups ? " AND rooms.direct_chat_matrix_id= '' " : "") +
            " GROUP BY rooms.id " +
            " ORDER BY origin_server_ts DESC ");
    List<Room> roomList = [];
    for (num i = 0; i < res.length; i++) {
      try {
        Room room = await Room.getRoomFromTableRow(res[i], client);
        roomList.add(room);
      } catch (e) {
        print(e.toString());
      }
    }
    return roomList;
  }

  /// Returns a room without events and participants.
  Future<Room> getRoomById(String id) async {
    List<Map<String, dynamic>> res =
        await db.rawQuery("SELECT * FROM Rooms WHERE id=?", [id]);
    if (res.length != 1) return null;
    return Room.getRoomFromTableRow(res[0], client);
  }

  /// Returns a room without events and participants.
  Future<Room> getRoomByAlias(String alias) async {
    List<Map<String, dynamic>> res = await db
        .rawQuery("SELECT * FROM Rooms WHERE canonical_alias=?", [alias]);
    if (res.length != 1) return null;
    return Room.getRoomFromTableRow(res[0], client);
  }

  /// Calculates and returns an avatar for a direct chat by a given [roomID].
  Future<String> getAvatarFromSingleChat(String roomID) async {
    String avatarStr = "";
    List<Map<String, dynamic>> res = await db.rawQuery(
        "SELECT avatar_url FROM Users " +
            " WHERE Users.chat_id=? " +
            " AND (Users.membership='join' OR Users.membership='invite') " +
            " AND Users.matrix_id!=? ",
        [roomID, client.userID]);
    if (res.length == 1) avatarStr = res[0]["avatar_url"];
    return avatarStr;
  }

  /// Calculates a chat name for a groupchat without a name. The chat name will
  /// be the name of all users (excluding the user of this client) divided by
  /// ','.
  Future<String> getChatNameFromMemberNames(String roomID) async {
    String displayname = 'Empty chat';
    List<Map<String, dynamic>> rs = await db.rawQuery(
        "SELECT Users.displayname, Users.matrix_id, Users.membership FROM Users " +
            " WHERE Users.chat_id=? " +
            " AND (Users.membership='join' OR Users.membership='invite') " +
            " AND Users.matrix_id!=? ",
        [roomID, client.userID]);
    if (rs.length > 0) {
      displayname = "";
      for (var i = 0; i < rs.length; i++) {
        String username = rs[i]["displayname"];
        if (username == "" || username == null) username = rs[i]["matrix_id"];
        if (rs[i]["state_key"] != client.userID) displayname += username + ", ";
      }
      if (displayname == "" || displayname == null)
        displayname = 'Empty chat';
      else
        displayname = displayname.substring(0, displayname.length - 2);
    }
    return displayname;
  }

  /// Returns the (first) room ID from the store which is a private chat with
  /// the user [userID]. Returns null if there is none.
  Future<String> getDirectChatRoomID(String userID) async {
    List<Map<String, dynamic>> res = await db.rawQuery(
        "SELECT id FROM Rooms WHERE direct_chat_matrix_id=? AND membership!='leave' LIMIT 1",
        [userID]);
    if (res.length != 1) return null;
    return res[0]["id"];
  }

  /// Returns the power level of the user for the given [roomID]. Returns null if
  /// the room or the own user wasn't found.
  Future<int> getPowerLevel(String roomID) async {
    List<Map<String, dynamic>> res = await db.rawQuery(
        "SELECT power_level FROM Users WHERE matrix_id=? AND chat_id=?",
        [roomID, client.userID]);
    if (res.length != 1) return null;
    return res[0]["power_level"];
  }

  /// Returns the power levels from all users for the given [roomID].
  Future<Map<String, int>> getPowerLevels(String roomID) async {
    List<Map<String, dynamic>> res = await db.rawQuery(
        "SELECT matrix_id, power_level FROM Users WHERE chat_id=?",
        [roomID, client.userID]);
    Map<String, int> powerMap = {};
    for (int i = 0; i < res.length; i++)
      powerMap[res[i]["matrix_id"]] = res[i]["power_level"];
    return powerMap;
  }

  Future<Map<String, List<String>>> getAccountDataDirectChats() async {
    Map<String, List<String>> directChats = {};
    List<Map<String, dynamic>> res = await db.rawQuery(
        "SELECT id, direct_chat_matrix_id FROM Rooms WHERE direct_chat_matrix_id!=''");
    for (int i = 0; i < res.length; i++) {
      if (directChats.containsKey(res[i]["direct_chat_matrix_id"]))
        directChats[res[i]["direct_chat_matrix_id"]].add(res[i]["id"]);
      else
        directChats[res[i]["direct_chat_matrix_id"]] = [res[i]["id"]];
    }
    return directChats;
  }

  Future<void> forgetRoom(String roomID) async {
    await db.rawDelete("DELETE FROM Rooms WHERE id=?", [roomID]);
    return;
  }

  /// Searches for the event in the store.
  Future<Event> getEventById(String eventID, Room room) async {
    List<Map<String, dynamic>> res = await db.rawQuery(
        "SELECT * FROM Events WHERE id=? AND chat_id=?", [eventID, room.id]);
    if (res.length == 0) return null;
    return Event.fromJson(res[0], room,
        senderUser: (await room.getUserByMXID(res[0]["sender"])));
  }

  Future forgetNotification(String roomID) async {
    await db
        .rawDelete("DELETE FROM NotificationsCache WHERE chat_id=?", [roomID]);
    return;
  }

  Future addNotification(String roomID, String event_id, int uniqueID) async {
    await db.rawInsert("INSERT INTO NotificationsCache VALUES (?, ?,?)",
        [uniqueID, roomID, event_id]);
    return;
  }

  Future<List<Map<String, dynamic>>> getNotificationByRoom(
      String room_id) async {
    List<Map<String, dynamic>> res = await db.rawQuery(
        "SELECT * FROM NotificationsCache WHERE chat_id=?", [room_id]);
    if (res.length == 0) return null;
    return res;
  }

  static final Map<String, String> schemes = {
    /// The database scheme for the Client class.
    "Clients": 'CREATE TABLE IF NOT EXISTS Clients(' +
        'client TEXT PRIMARY KEY, ' +
        'token TEXT, ' +
        'homeserver TEXT, ' +
        'matrix_id TEXT, ' +
        'device_id TEXT, ' +
        'device_name TEXT, ' +
        'prev_batch TEXT, ' +
        'matrix_versions TEXT, ' +
        'lazy_load_members INTEGER, ' +
        'UNIQUE(client))',

    /// The database scheme for the Room class.
    "Rooms": 'CREATE TABLE IF NOT EXISTS Rooms(' +
        'id TEXT PRIMARY KEY, ' +
        'membership TEXT, ' +
        'topic TEXT, ' +
        'highlight_count INTEGER, ' +
        'notification_count INTEGER, ' +
        'prev_batch TEXT, ' +
        'avatar_url TEXT, ' +
        'draft TEXT, ' +
        'unread INTEGER, ' + // Timestamp of when the user has last read the chat
        'fully_read TEXT, ' + // ID of the fully read marker event
        'description TEXT, ' +
        'canonical_alias TEXT, ' + // The address in the form: #roomname:homeserver.org
        'direct_chat_matrix_id TEXT, ' + //If this room is a direct chat, this is the matrix ID of the user
        'notification_settings TEXT, ' + // Must be one of [all, mention]

        // Security rules
        'guest_access TEXT, ' +
        'history_visibility TEXT, ' +
        'join_rules TEXT, ' +

        // Power levels
        'power_events_default INTEGER, ' +
        'power_state_default INTEGER, ' +
        'power_redact INTEGER, ' +
        'power_invite INTEGER, ' +
        'power_ban INTEGER, ' +
        'power_kick INTEGER, ' +
        'power_user_default INTEGER, ' +

        // Power levels for events
        'power_event_avatar INTEGER, ' +
        'power_event_history_visibility INTEGER, ' +
        'power_event_canonical_alias INTEGER, ' +
        'power_event_aliases INTEGER, ' +
        'power_event_name INTEGER, ' +
        'power_event_power_levels INTEGER, ' +
        'UNIQUE(id))',

    /// The database scheme for the Event class.
    "Events": 'CREATE TABLE IF NOT EXISTS Events(' +
        'id TEXT PRIMARY KEY, ' +
        'chat_id TEXT, ' +
        'origin_server_ts INTEGER, ' +
        'sender TEXT, ' +
        'state_key TEXT, ' +
        'content_body TEXT, ' +
        'type TEXT, ' +
        'content_json TEXT, ' +
        "status INTEGER, " +
        'UNIQUE(id))',

    /// The database scheme for the User class.
    "Users": 'CREATE TABLE IF NOT EXISTS Users(' +
        'chat_id TEXT, ' + // The chat id of this membership
        'matrix_id TEXT, ' + // The matrix id of this user
        'displayname TEXT, ' +
        'avatar_url TEXT, ' +
        'membership TEXT, ' + // The status of the membership. Must be one of [join, invite, ban, leave]
        'power_level INTEGER, ' + // The power level of this user. Must be in [0,..,100]
        'UNIQUE(chat_id, matrix_id))',

    /// The database scheme for the NotificationsCache class.
    "NotificationsCache": 'CREATE TABLE IF NOT EXISTS NotificationsCache(' +
        'id int PRIMARY KEY, ' +
        'chat_id TEXT, ' + // The chat id
        'event_id TEXT, ' + // The matrix id of the Event
        'UNIQUE(event_id))',
  };
}
