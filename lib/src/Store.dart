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
 * along with Foobar.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'sync/EventUpdate.dart';
import 'sync/RoomUpdate.dart';
import 'Client.dart';
import 'User.dart';
import 'Room.dart';
import 'Connection.dart';

/// Represents a Matrix connection to communicate with a
/// [Matrix](https://matrix.org) homeserver.
class Store {

  final Client client;

  Store(this.client) {
    _init();
  }

  Database _db;

  /// SQLite database for all persistent data. It is recommended to extend this
  /// SDK instead of writing direct queries to the database.
  Database get db => _db;

  _init() async{
    var databasePath = await getDatabasesPath();
    String path = p.join(databasePath, "FluffyMatrix.db");
    _db = await openDatabase(path, version: 2,
        onCreate: (Database db, int version) async {
          // When creating the db, create the table
          await db.execute(ClientScheme);
          await db.execute(RoomScheme);
          await db.execute(MemberScheme);
          await db.execute(EventScheme);
        });

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
        newPrevBatch: clientList["prev_batch"],
      );
      print("Restore client credentials of ${client.userID}");
    } else
      client.connection.onLoginStateChanged.add(LoginState.loggedOut);
  }

  Future<String> queryPrevBatch() async{
    List<Map> list = await txn.rawQuery("SELECT prev_batch FROM Clients WHERE client=?", [client.clientName]);
    return list[0]["prev_batch"];
  }

  /// Will be automatically called when the client is logged in successfully.
  Future<void> storeClient() async{
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
  Future<void> clear() async{
    await _db.rawDelete("DELETE FROM Clients WHERE client=?", [client.clientName]);
    await _db.rawDelete("DELETE FROM Chats");
    await _db.rawDelete("DELETE FROM Memberships");
    await _db.rawDelete("DELETE FROM Events");
    return;
  }

  Transaction txn;

  Future<void> transaction(Future<void> queries()) async{
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
  }

  /// Stores a RoomUpdate object in the database. Must be called inside of
  /// [transaction].
  Future<void> storeRoomUpdate(RoomUpdate roomUpdate) {
    // Insert the chat into the database if not exists
   txn.rawInsert(
        "INSERT OR IGNORE INTO Chats " +
            "VALUES(?, ?, '', 0, 0, 0, '', '', '', 0, '', '', '', '', '', '', 0, 50, 50, 0, 50, 50, 0, 50, 100, 50, 50, 50, 100) ",
        [roomUpdate.id, roomUpdate.membership]);

    // Update the notification counts and the limited timeline boolean
    txn.rawUpdate(
        "UPDATE Chats SET highlight_count=?, notification_count=?, membership=?, limitedTimeline=? WHERE id=? ",
        [
          roomUpdate.highlight_count,
          roomUpdate.notification_count,
          roomUpdate.membership,
          roomUpdate.limitedTimeline,
          roomUpdate.id
        ]);

    // Is the timeline limited? Then all previous messages should be
    // removed from the database!
    if (roomUpdate.limitedTimeline) {
      txn.rawDelete("DELETE FROM Events WHERE chat_id=?", [roomUpdate.id]);
      txn.rawUpdate("UPDATE Chats SET prev_batch=? WHERE id=?",
          [roomUpdate.prev_batch, roomUpdate.id]);
    }
  }

  /// Stores an EventUpdate object in the database. Must be called inside of
  //  /// [transaction].
  Future<void> storeEventUpdate(EventUpdate eventUpdate) {
    dynamic eventContent = eventUpdate.content;
    String type = eventUpdate.type;
    String chat_id = eventUpdate.roomID;

    if (type == "timeline" || type == "history") {
      // calculate the status
      num status = 2;
      // Make unsigned part of the content
      if (eventContent["unsigned"] is Map<String, dynamic>)
        eventContent["content"]["unsigned"] = eventContent["unsigned"];

      // Get the state_key for m.room.member events
      String state_key = "";
      if (eventContent["state_key"] is String) {
        state_key = eventContent["state_key"];
      }

      // Save the event in the database

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
    }

    if (type == "history") return null;

    switch (eventUpdate.eventType) {
      case "m.receipt":
        if (eventContent["user"] == client.userID) {
          txn.rawUpdate("UPDATE Chats SET unread=? WHERE id=?",
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
        txn.rawUpdate("UPDATE Chats SET topic=? WHERE id=?",
            [eventContent["content"]["name"], chat_id]);
        break;
    // This event means, that the topic of a room has been changed, so
    // it has to be changed in the database
      case "m.room.topic":
        txn.rawUpdate("UPDATE Chats SET description=? WHERE id=?",
            [eventContent["content"]["topic"], chat_id]);
        break;
    // This event means, that the topic of a room has been changed, so
    // it has to be changed in the database
      case "m.room.history_visibility":
        txn.rawUpdate("UPDATE Chats SET history_visibility=? WHERE id=?",
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
        txn.rawUpdate("UPDATE Chats SET guest_access=? WHERE id=?",
            [eventContent["content"]["guest_access"], chat_id]);
        break;
    // This event means, that the topic of a room has been changed, so
    // it has to be changed in the database
      case "m.room.join_rules":
        txn.rawUpdate("UPDATE Chats SET join_rules=? WHERE id=?",
            [eventContent["content"]["join_rule"], chat_id]);
        break;
    // This event means, that the avatar of a room has been changed, so
    // it has to be changed in the database
      case "m.room.avatar":
        txn.rawUpdate("UPDATE Chats SET avatar_url=? WHERE id=?",
            [eventContent["content"]["url"], chat_id]);
        break;
    // This event means, that the aliases of a room has been changed, so
    // it has to be changed in the database
      case "m.fully_read":
        txn.rawUpdate("UPDATE Chats SET fully_read=? WHERE id=?",
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
       txn.rawInsert("INSERT OR IGNORE INTO Memberships VALUES(?,?,?,?,?,0)", [
          chat_id,
          state_key,
          insertDisplayname,
          insertAvatarUrl,
          membership
        ]);
        String queryStr = "UPDATE Memberships SET membership=?";
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
        String query = "UPDATE Chats SET ";
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
        if (query != "UPDATE Chats SET ") {
          query = query.replaceFirst(",", "");
          txn.rawUpdate(query + " WHERE id=?", [chat_id]);
        }

        // Set the users power levels:
        if (eventContent["content"]["users"] is Map<String, dynamic>) {
          eventContent["content"]["users"]
              .forEach((String user, dynamic value) async {
            num power_level = eventContent["content"]["users"][user];
            txn.rawUpdate(
                "UPDATE Memberships SET power_level=? WHERE matrix_id=? AND chat_id=?",
                [power_level, user, chat_id]);
           txn.rawInsert(
                "INSERT OR IGNORE INTO Memberships VALUES(?, ?, '', '', ?, ?)",
                [chat_id, user, "unknown", power_level]);
          });
        }
        break;
    }
  }

  /// Returns a User object by a given Matrix ID and a Room ID.
  Future<User> getUser(
      {String matrixID, String roomID}) async {
    List<Map<String, dynamic>> res = await db.rawQuery(
        "SELECT * FROM Memberships WHERE matrix_id=? AND chat_id=?",
        [matrixID, roomID]);
    if (res.length != 1) return null;
    return User.fromJson(res[0]);
  }

  /// Loads all Users in the database to provide a contact list.
  Future<List<User>> loadContacts() async {
    List<Map<String, dynamic>> res = await db.rawQuery(
        "SELECT * FROM Memberships WHERE matrix_id!=? GROUP BY matrix_id ORDER BY displayname",
        [client.userID]);
    List<User> userList = [];
    for (int i = 0; i < res.length; i++) userList.add(User.fromJson(res[i]));
    return userList;
  }

  /// Returns all users of a room by a given [roomID].
  Future<List<User>> loadParticipants(String roomID) async {
    List<Map<String, dynamic>> res = await db.rawQuery(
        "SELECT * " +
            " FROM Memberships " +
            " WHERE chat_id=? " +
            " AND membership='join'",
        [roomID]);

    List<User> participants = [];

    for (num i = 0; i < res.length; i++) {
      participants.add(User.fromJson(res[i]));
    }

    return participants;
  }

  /// Returns all rooms, the client is participating. Excludes left rooms.
  Future<List<Room>> getRoomList() async {
    List<Map<String, dynamic>> res = await db.rawQuery(
        "SELECT rooms.id, rooms.topic, rooms.membership, rooms.notification_count, rooms.highlight_count, rooms.avatar_url, rooms.unread, " +
            " events.id AS eventsid, origin_server_ts, events.content_body, events.sender, events.state_key, events.content_json, events.type " +
            " FROM Chats rooms LEFT JOIN Events events " +
            " ON rooms.id=events.chat_id " +
            " WHERE rooms.membership!='leave' " +
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

  /// Calculates and returns an avatar for a direct chat by a given [roomID].
  Future<String> getAvatarFromSingleChat(
      String roomID) async {
    String avatarStr = "";
    List<Map<String, dynamic>> res = await db.rawQuery(
        "SELECT avatar_url FROM Memberships " +
            " WHERE Memberships.chat_id=? " +
            " AND (Memberships.membership='join' OR Memberships.membership='invite') " +
            " AND Memberships.matrix_id!=? ",
        [roomID, client.userID]);
    if (res.length == 1) avatarStr = res[0]["avatar_url"];
    return avatarStr;
  }

  /// Calculates a chat name for a groupchat without a name. The chat name will
  /// be the name of all users (excluding the user of this client) divided by
  /// ','.
  Future<String> getChatNameFromMemberNames(
      String roomID) async {
    String displayname = 'Empty chat';
    List<Map<String, dynamic>> rs = await db.rawQuery(
        "SELECT Memberships.displayname, Memberships.matrix_id, Memberships.membership FROM Memberships " +
            " WHERE Memberships.chat_id=? " +
            " AND (Memberships.membership='join' OR Memberships.membership='invite') " +
            " AND Memberships.matrix_id!=? ",
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

  /// The database sheme for the Client class.
  static final String ClientScheme = 'CREATE TABLE IF NOT EXISTS Clients(' +
      'client TEXT PRIMARY KEY, ' +
      'token TEXT, ' +
      'homeserver TEXT, ' +
      'matrix_id TEXT, ' +
      'device_id TEXT, ' +
      'device_name TEXT, ' +
      'prev_batch TEXT, ' +
      'matrix_versions TEXT, ' +
      'lazy_load_members INTEGER, ' +
      'UNIQUE(client))';
  /// The database sheme for the Room class.
  static final String RoomScheme = 'CREATE TABLE IF NOT EXISTS Chats(' +
      'id TEXT PRIMARY KEY, ' +
      'membership TEXT, ' +
      'topic TEXT, ' +
      'highlight_count INTEGER, ' +
      'notification_count INTEGER, ' +
      'limitedTimeline INTEGER, ' +
      'prev_batch TEXT, ' +
      'avatar_url TEXT, ' +
      'draft TEXT, ' +
      'unread INTEGER, ' + // Timestamp of when the user has last read the chat
      'fully_read TEXT, ' + // ID of the fully read marker event
      'description TEXT, ' +
      'canonical_alias TEXT, ' + // The address in the form: #roomname:homeserver.org

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
      'UNIQUE(id))';

  /// The database sheme for the Event class.
  static final String EventScheme = 'CREATE TABLE IF NOT EXISTS Events(' +
      'id TEXT PRIMARY KEY, ' +
      'chat_id TEXT, ' +
      'origin_server_ts INTEGER, ' +
      'sender TEXT, ' +
      'state_key TEXT, ' +
      'content_body TEXT, ' +
      'type TEXT, ' +
      'content_json TEXT, ' +
      "status INTEGER, " +
      'UNIQUE(id))';

  /// The database sheme for the User class.
  static final String MemberScheme = 'CREATE TABLE IF NOT EXISTS Memberships(' +
      'chat_id TEXT, ' + // The chat id of this membership
      'matrix_id TEXT, ' + // The matrix id of this user
      'displayname TEXT, ' +
      'avatar_url TEXT, ' +
      'membership TEXT, ' + // The status of the membership. Must be one of [join, invite, ban, leave]
      'power_level INTEGER, ' + // The power level of this user. Must be in [0,..,100]
      'UNIQUE(chat_id, matrix_id))';
}