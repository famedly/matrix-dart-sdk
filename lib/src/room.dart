/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020 Famedly GmbH
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

import 'package:famedlysdk/matrix_api.dart';
import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/src/client.dart';
import 'package:famedlysdk/src/event.dart';
import 'package:famedlysdk/src/utils/event_update.dart';
import 'package:famedlysdk/src/utils/room_update.dart';
import 'package:famedlysdk/src/utils/matrix_file.dart';
import 'package:matrix_file_e2ee/matrix_file_e2ee.dart';
import 'package:html_unescape/html_unescape.dart';

import './user.dart';
import 'timeline.dart';
import 'utils/matrix_localizations.dart';
import 'utils/states_map.dart';
import './utils/markdown.dart';
import './database/database.dart' show DbRoom;

enum PushRuleState { notify, mentions_only, dont_notify }
enum JoinRules { public, knock, invite, private }
enum GuestAccess { can_join, forbidden }
enum HistoryVisibility { invited, joined, shared, world_readable }

/// Represents a Matrix room.
class Room {
  /// The full qualified Matrix ID for the room in the format '!localid:server.abc'.
  final String id;

  /// Membership status of the user for this room.
  Membership membership;

  /// The count of unread notifications.
  int notificationCount;

  /// The count of highlighted notifications.
  int highlightCount;

  /// A token that can be supplied to the from parameter of the rooms/{roomId}/messages endpoint.
  String prev_batch;

  /// The users which can be used to generate a room name if the room does not have one.
  /// Required if the room's m.room.name or m.room.canonical_alias state events are unset or empty.
  List<String> mHeroes = [];

  /// The number of users with membership of join, including the client's own user ID.
  int mJoinedMemberCount;

  /// The number of users with membership of invite.
  int mInvitedMemberCount;

  StatesMap states = StatesMap();

  /// Key-Value store for ephemerals.
  Map<String, BasicRoomEvent> ephemerals = {};

  /// Key-Value store for private account data only visible for this user.
  Map<String, BasicRoomEvent> roomAccountData = {};

  double _newestSortOrder;
  double _oldestSortOrder;

  double get newSortOrder {
    var now = DateTime.now().millisecondsSinceEpoch.toDouble();
    if (_newestSortOrder >= now) {
      now = _newestSortOrder + 1;
    }
    _newestSortOrder = now;
    return _newestSortOrder;
  }

  double get oldSortOrder {
    _oldestSortOrder--;
    return _oldestSortOrder;
  }

  void resetSortOrder() {
    _oldestSortOrder = _newestSortOrder = 0.0;
  }

  Future<void> updateSortOrder() async {
    await client.database?.updateRoomSortOrder(
        _oldestSortOrder, _newestSortOrder, client.id, id);
  }

  /// Flag if the room is partial, meaning not all state events have been loaded yet
  bool partial = true;

  /// Load all the missing state events for the room from the database. If the room has already been loaded, this does nothing.
  Future<void> postLoad() async {
    if (!partial || client.database == null) {
      return;
    }
    final allStates = await client.database
        .getUnimportantRoomStatesForRoom(
            client.id, id, client.importantStateEvents.toList())
        .get();
    for (final state in allStates) {
      final newState = Event.fromDb(state, this);
      setState(newState);
    }
    partial = false;
  }

  /// Returns the [Event] for the given [typeKey] and optional [stateKey].
  /// If no [stateKey] is provided, it defaults to an empty string.
  Event getState(String typeKey, [String stateKey = '']) =>
      states.states[typeKey] != null ? states.states[typeKey][stateKey] : null;

  /// Adds the [state] to this room and overwrites a state with the same
  /// typeKey/stateKey key pair if there is one.
  void setState(Event state) {
    // Decrypt if necessary
    if (state.type == EventTypes.Encrypted && client.encryptionEnabled) {
      try {
        state = client.encryption.decryptRoomEventSync(id, state);
      } catch (e) {
        print('[LibOlm] Could not decrypt room state: ' + e.toString());
      }
    }
    if (!(state.stateKey is String) &&
        ![EventTypes.Message, EventTypes.Sticker, EventTypes.Encrypted]
            .contains(state.type)) {
      return;
    }
    if ((getState(state.type, state.stateKey ?? '')
                ?.originServerTs
                ?.millisecondsSinceEpoch ??
            0) >
        (state.originServerTs?.millisecondsSinceEpoch ?? 1)) {
      return;
    }
    if (!states.states.containsKey(state.type)) {
      states.states[state.type] = {};
    }
    states.states[state.type][state.stateKey ?? ''] = state;
  }

  /// ID of the fully read marker event.
  String get fullyRead => roomAccountData['m.fully_read'] != null
      ? roomAccountData['m.fully_read'].content['event_id']
      : '';

  /// If something changes, this callback will be triggered. Will return the
  /// room id.
  final StreamController<String> onUpdate = StreamController.broadcast();

  /// If there is a new session key received, this will be triggered with
  /// the session ID.
  final StreamController<String> onSessionKeyReceived =
      StreamController.broadcast();

  /// The name of the room if set by a participant.
  String get name => states[EventTypes.RoomName] != null
      ? states[EventTypes.RoomName].content['name']
      : '';

  /// The pinned events for this room. If there are no this returns an empty
  /// list.
  List<String> get pinnedEventIds => states[EventTypes.RoomPinnedEvents] != null
      ? (states[EventTypes.RoomPinnedEvents].content['pinned'] is List<String>
          ? states[EventTypes.RoomPinnedEvents].content['pinned']
          : <String>[])
      : <String>[];

  /// Returns a localized displayname for this server. If the room is a groupchat
  /// without a name, then it will return the localized version of 'Group with Alice' instead
  /// of just 'Alice' to make it different to a direct chat.
  /// Empty chats will become the localized version of 'Empty Chat'.
  /// This method requires a localization class which implements [MatrixLocalizations]
  String getLocalizedDisplayname(MatrixLocalizations i18n) {
    if ((name?.isEmpty ?? true) &&
        (canonicalAlias?.isEmpty ?? true) &&
        !isDirectChat &&
        (mHeroes != null && mHeroes.isNotEmpty)) {
      return i18n.groupWith(displayname);
    }
    if (displayname?.isNotEmpty ?? false) {
      return displayname;
    }
    return i18n.emptyChat;
  }

  /// The topic of the room if set by a participant.
  String get topic => states[EventTypes.RoomTopic] != null
      ? states[EventTypes.RoomTopic].content['topic']
      : '';

  /// The avatar of the room if set by a participant.
  Uri get avatar {
    if (states[EventTypes.RoomAvatar] != null &&
        states[EventTypes.RoomAvatar].content['url'] != null) {
      return Uri.parse(states[EventTypes.RoomAvatar].content['url']);
    }
    if (mHeroes != null && mHeroes.length == 1 && states[mHeroes[0]] != null) {
      return states[mHeroes[0]].asUser.avatarUrl;
    }
    if (membership == Membership.invite &&
        getState(EventTypes.RoomMember, client.userID) != null) {
      return getState(EventTypes.RoomMember, client.userID).sender.avatarUrl;
    }
    return null;
  }

  /// The address in the format: #roomname:homeserver.org.
  String get canonicalAlias => states[EventTypes.RoomCanonicalAlias] != null &&
          states[EventTypes.RoomCanonicalAlias].content['alias'] is String
      ? states[EventTypes.RoomCanonicalAlias].content['alias']
      : '';

  /// If this room is a direct chat, this is the matrix ID of the user.
  /// Returns null otherwise.
  String get directChatMatrixID {
    String returnUserId;
    if (client.directChats is Map<String, dynamic>) {
      client.directChats.forEach((String userId, dynamic roomIds) {
        if (roomIds is List<dynamic>) {
          for (var i = 0; i < roomIds.length; i++) {
            if (roomIds[i] == id) {
              returnUserId = userId;
              break;
            }
          }
        }
      });
    }
    return returnUserId;
  }

  /// Wheither this is a direct chat or not
  bool get isDirectChat => directChatMatrixID != null;

  /// Must be one of [all, mention]
  String notificationSettings;

  Event get lastEvent {
    // as lastEvent calculation is based on the state events we unfortunately cannot
    // use sortOrder here: With many state events we just know which ones are the
    // newest ones, without knowing in which order they actually happened. As such,
    // using the origin_server_ts is the best guess for this algorithm. While not
    // perfect, it is only used for the room preview in the room list and sorting
    // said room list, so it should be good enough.
    var lastTime = DateTime.fromMillisecondsSinceEpoch(0);
    var lastEvent = getState(EventTypes.Message);
    if (lastEvent == null) {
      states.forEach((final String key, final entry) {
        if (!entry.containsKey('')) return;
        final Event state = entry[''];
        if (state.originServerTs != null &&
            state.originServerTs.millisecondsSinceEpoch >
                lastTime.millisecondsSinceEpoch) {
          lastTime = state.originServerTs;
          lastEvent = state;
        }
      });
    }
    return lastEvent;
  }

  /// Returns a list of all current typing users.
  List<User> get typingUsers {
    if (!ephemerals.containsKey('m.typing')) return [];
    List<dynamic> typingMxid = ephemerals['m.typing'].content['user_ids'];
    var typingUsers = <User>[];
    for (var i = 0; i < typingMxid.length; i++) {
      typingUsers.add(getUserByMXIDSync(typingMxid[i]));
    }
    return typingUsers;
  }

  /// Your current client instance.
  final Client client;

  Room({
    this.id,
    this.membership = Membership.join,
    this.notificationCount = 0,
    this.highlightCount = 0,
    this.prev_batch = '',
    this.client,
    this.notificationSettings,
    this.mHeroes = const [],
    this.mInvitedMemberCount = 0,
    this.mJoinedMemberCount = 0,
    this.roomAccountData = const {},
    double newestSortOrder = 0.0,
    double oldestSortOrder = 0.0,
  })  : _newestSortOrder = newestSortOrder,
        _oldestSortOrder = oldestSortOrder;

  /// The default count of how much events should be requested when requesting the
  /// history of this room.
  static const int DefaultHistoryCount = 100;

  /// Calculates the displayname. First checks if there is a name, then checks for a canonical alias and
  /// then generates a name from the heroes.
  String get displayname {
    if (name != null && name.isNotEmpty) return name;
    if (canonicalAlias != null &&
        canonicalAlias.isNotEmpty &&
        canonicalAlias.length > 3) {
      return canonicalAlias.localpart;
    }
    var heroes = <String>[];
    if (mHeroes != null &&
        mHeroes.isNotEmpty &&
        mHeroes.any((h) => h.isNotEmpty)) {
      heroes = mHeroes;
    } else {
      if (states[EventTypes.RoomMember] is Map<String, dynamic>) {
        for (var entry in states[EventTypes.RoomMember].entries) {
          Event state = entry.value;
          if (state.type == EventTypes.RoomMember &&
              state.stateKey != client?.userID) heroes.add(state.stateKey);
        }
      }
    }
    if (heroes.isNotEmpty) {
      var displayname = '';
      for (var i = 0; i < heroes.length; i++) {
        if (heroes[i].isEmpty) continue;
        displayname += getUserByMXIDSync(heroes[i]).calcDisplayname() + ', ';
      }
      return displayname.substring(0, displayname.length - 2);
    }
    if (membership == Membership.invite &&
        getState(EventTypes.RoomMember, client.userID) != null) {
      return getState(EventTypes.RoomMember, client.userID)
          .sender
          .calcDisplayname();
    }
    return 'Empty chat';
  }

  /// The last message sent to this room.
  String get lastMessage {
    if (lastEvent != null) {
      return lastEvent.body;
    } else {
      return '';
    }
  }

  /// When the last message received.
  DateTime get timeCreated {
    if (lastEvent != null) {
      return lastEvent.originServerTs;
    }
    return DateTime.now();
  }

  /// Call the Matrix API to change the name of this room. Returns the event ID of the
  /// new m.room.name event.
  Future<String> setName(String newName) => client.api.sendState(
        id,
        EventTypes.RoomName,
        {'name': newName},
      );

  /// Call the Matrix API to change the topic of this room.
  Future<String> setDescription(String newName) => client.api.sendState(
        id,
        EventTypes.RoomTopic,
        {'topic': newName},
      );

  /// Add a tag to the room.
  Future<void> addTag(String tag, {double order}) => client.api.addRoomTag(
        client.userID,
        id,
        tag,
        order: order,
      );

  /// Removes a tag from the room.
  Future<void> removeTag(String tag) => client.api.removeRoomTag(
        client.userID,
        id,
        tag,
      );

  /// Returns all tags for this room.
  Map<String, Tag> get tags {
    if (roomAccountData['m.tag'] == null ||
        !(roomAccountData['m.tag'].content['tags'] is Map)) {
      return {};
    }
    final tags = (roomAccountData['m.tag'].content['tags'] as Map)
        .map((k, v) => MapEntry<String, Tag>(k, Tag.fromJson(v)));
    tags.removeWhere((k, v) => !TagType.isValid(k));
    return tags;
  }

  /// Returns true if this room has a m.favourite tag.
  bool get isFavourite => tags[TagType.Favourite] != null;

  /// Sets the m.favourite tag for this room.
  Future<void> setFavourite(bool favourite) =>
      favourite ? addTag(TagType.Favourite) : removeTag(TagType.Favourite);

  /// Call the Matrix API to change the pinned events of this room.
  Future<String> setPinnedEvents(List<String> pinnedEventIds) =>
      client.api.sendState(
        id,
        EventTypes.RoomPinnedEvents,
        {'pinned': pinnedEventIds},
      );

  /// return all current emote packs for this room
  Map<String, Map<String, String>> get emotePacks {
    final packs = <String, Map<String, String>>{};
    final normalizeEmotePackName = (String name) {
      name = name.replaceAll(' ', '-');
      name = name.replaceAll(RegExp(r'[^\w-]'), '');
      return name.toLowerCase();
    };
    final addEmotePack = (String packName, Map<String, dynamic> content,
        [String packNameOverride]) {
      if (!(content['short'] is Map)) {
        return;
      }
      if (content['pack'] is Map && content['pack']['name'] is String) {
        packName = content['pack']['name'];
      }
      if (packNameOverride != null && packNameOverride.isNotEmpty) {
        packName = packNameOverride;
      }
      packName = normalizeEmotePackName(packName);
      if (!packs.containsKey(packName)) {
        packs[packName] = <String, String>{};
      }
      content['short'].forEach((key, value) {
        if (key is String && value is String && value.startsWith('mxc://')) {
          packs[packName][key] = value;
        }
      });
    };
    // first add all the room emotes
    final allRoomEmotes = states.states['im.ponies.room_emotes'];
    if (allRoomEmotes != null) {
      for (final entry in allRoomEmotes.entries) {
        final stateKey = entry.key;
        final event = entry.value;
        addEmotePack(stateKey.isEmpty ? 'room' : stateKey, event.content);
      }
    }
    // next add all the user emotes
    final userEmotes = client.accountData['im.ponies.user_emotes'];
    if (userEmotes != null) {
      addEmotePack('user', userEmotes.content);
    }
    // finally add all the external emote rooms
    final emoteRooms = client.accountData['im.ponies.emote_rooms'];
    if (emoteRooms != null && emoteRooms.content['rooms'] is Map) {
      for (final roomEntry in emoteRooms.content['rooms'].entries) {
        final roomId = roomEntry.key;
        if (roomId == id) {
          continue;
        }
        final room = client.getRoomById(roomId);
        if (room != null && roomEntry.value is Map) {
          for (final stateKeyEntry in roomEntry.value.entries) {
            final stateKey = stateKeyEntry.key;
            final event = room.getState('im.ponies.room_emotes', stateKey);
            if (event != null && stateKeyEntry.value is Map) {
              addEmotePack(
                  (room.canonicalAlias?.isEmpty ?? true)
                      ? room.id
                      : canonicalAlias,
                  event.content,
                  stateKeyEntry.value['name']);
            }
          }
        }
      }
    }
    return packs;
  }

  /// Sends a normal text message to this room. Returns the event ID generated
  /// by the server for this message.
  Future<String> sendTextEvent(String message,
      {String txid,
      Event inReplyTo,
      bool parseMarkdown = true,
      Map<String, Map<String, String>> emotePacks}) {
    final event = <String, dynamic>{
      'msgtype': 'm.text',
      'body': message,
    };
    if (message.startsWith('/me ')) {
      event['msgtype'] = 'm.emote';
      event['body'] = message.substring(4);
    }
    if (parseMarkdown) {
      final html = markdown(event['body'], emotePacks ?? this.emotePacks);
      // if the decoded html is the same as the body, there is no need in sending a formatted message
      if (HtmlUnescape().convert(html) != event['body']) {
        event['format'] = 'org.matrix.custom.html';
        event['formatted_body'] = html;
      }
    }
    return sendEvent(event, txid: txid, inReplyTo: inReplyTo);
  }

  /// Sends a [file] to this room after uploading it. Returns the mxc uri of
  /// the uploaded file. If [waitUntilSent] is true, the future will wait until
  /// the message event has received the server. Otherwise the future will only
  /// wait until the file has been uploaded.
  Future<String> sendFileEvent(
    MatrixFile file, {
    String txid,
    Event inReplyTo,
    bool waitUntilSent = false,
    MatrixImageFile thumbnail,
  }) async {
    MatrixFile uploadFile = file; // ignore: omit_local_variable_types
    MatrixFile uploadThumbnail = thumbnail; // ignore: omit_local_variable_types
    EncryptedFile encryptedFile;
    EncryptedFile encryptedThumbnail;
    if (encrypted && client.fileEncryptionEnabled) {
      encryptedFile = await file.encrypt();
      uploadFile = encryptedFile.toMatrixFile();

      if (thumbnail != null) {
        encryptedThumbnail = await thumbnail.encrypt();
        uploadThumbnail = encryptedThumbnail.toMatrixFile();
      }
    }
    final uploadResp = await client.api.upload(
      uploadFile.bytes,
      uploadFile.name,
      contentType: uploadFile.mimeType,
    );
    final thumbnailUploadResp = uploadThumbnail != null
        ? await client.api.upload(
            uploadThumbnail.bytes,
            uploadThumbnail.name,
            contentType: uploadThumbnail.mimeType,
          )
        : null;

    // Send event
    var content = <String, dynamic>{
      'msgtype': file.msgType,
      'body': file.name,
      'filename': file.name,
      if (encryptedFile == null) 'url': uploadResp,
      if (encryptedFile != null)
        'file': {
          'url': uploadResp,
          'mimetype': file.mimeType,
          'v': 'v2',
          'key': {
            'alg': 'A256CTR',
            'ext': true,
            'k': encryptedFile.k,
            'key_ops': ['encrypt', 'decrypt'],
            'kty': 'oct'
          },
          'iv': encryptedFile.iv,
          'hashes': {'sha256': encryptedFile.sha256}
        },
      'info': {
        ...file.info,
        if (thumbnail != null && encryptedThumbnail == null)
          'thumbnail_url': thumbnailUploadResp,
        if (thumbnail != null && encryptedThumbnail != null)
          'thumbnail_file': {
            'url': thumbnailUploadResp,
            'mimetype': thumbnail.mimeType,
            'v': 'v2',
            'key': {
              'alg': 'A256CTR',
              'ext': true,
              'k': encryptedThumbnail.k,
              'key_ops': ['encrypt', 'decrypt'],
              'kty': 'oct'
            },
            'iv': encryptedThumbnail.iv,
            'hashes': {'sha256': encryptedThumbnail.sha256}
          },
        if (thumbnail != null) 'thumbnail_info': thumbnail.info,
      }
    };
    final sendResponse = sendEvent(
      content,
      txid: txid,
      inReplyTo: inReplyTo,
    );
    if (waitUntilSent) {
      await sendResponse;
    }
    return uploadResp;
  }

  /// Sends an event to this room with this json as a content. Returns the
  /// event ID generated from the server.
  Future<String> sendEvent(Map<String, dynamic> content,
      {String type, String txid, Event inReplyTo}) async {
    type = type ?? EventTypes.Message;
    final sendType =
        (encrypted && client.encryptionEnabled) ? EventTypes.Encrypted : type;

    // Create new transaction id
    String messageID;
    if (txid == null) {
      messageID = client.generateUniqueTransactionId();
    } else {
      messageID = txid;
    }

    if (inReplyTo != null) {
      var replyText = '<${inReplyTo.senderId}> ' + inReplyTo.body;
      var replyTextLines = replyText.split('\n');
      for (var i = 0; i < replyTextLines.length; i++) {
        replyTextLines[i] = '> ' + replyTextLines[i];
      }
      replyText = replyTextLines.join('\n');
      content['format'] = 'org.matrix.custom.html';
      content['formatted_body'] =
          '<mx-reply><blockquote><a href="https://matrix.to/#/${inReplyTo.room.id}/${inReplyTo.eventId}">In reply to</a> <a href="https://matrix.to/#/${inReplyTo.senderId}">${inReplyTo.senderId}</a><br>${inReplyTo.body}</blockquote></mx-reply>${content["formatted_body"] ?? content["body"]}';
      content['body'] = replyText + "\n\n${content["body"] ?? ""}";
      content['m.relates_to'] = {
        'm.in_reply_to': {
          'event_id': inReplyTo.eventId,
        },
      };
    }

    final sortOrder = newSortOrder;
    // Display a *sending* event and store it.
    var eventUpdate = EventUpdate(
      type: 'timeline',
      roomID: id,
      eventType: type,
      sortOrder: sortOrder,
      content: {
        'type': type,
        'event_id': messageID,
        'sender': client.userID,
        'status': 0,
        'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
        'content': content
      },
    );
    client.onEvent.add(eventUpdate);
    await client.database?.transaction(() async {
      await client.database.storeEventUpdate(client.id, eventUpdate);
      await updateSortOrder();
    });

    // Send the text and on success, store and display a *sent* event.
    try {
      final sendMessageContent = encrypted && client.encryptionEnabled
          ? await client.encryption
              .encryptGroupMessagePayload(id, content, type: type)
          : content;
      final res = await client.api.sendMessage(
        id,
        sendType,
        messageID,
        sendMessageContent,
      );
      eventUpdate.content['status'] = 1;
      eventUpdate.content['unsigned'] = {'transaction_id': messageID};
      eventUpdate.content['event_id'] = res;
      client.onEvent.add(eventUpdate);
      await client.database?.transaction(() async {
        await client.database.storeEventUpdate(client.id, eventUpdate);
      });
      return res;
    } catch (exception) {
      print('[Client] Error while sending: ' + exception.toString());
      // On error, set status to -1
      eventUpdate.content['status'] = -1;
      eventUpdate.content['unsigned'] = {'transaction_id': messageID};
      client.onEvent.add(eventUpdate);
      await client.database?.transaction(() async {
        await client.database.storeEventUpdate(client.id, eventUpdate);
      });
    }
    return null;
  }

  /// Call the Matrix API to join this room if the user is not already a member.
  /// If this room is intended to be a direct chat, the direct chat flag will
  /// automatically be set.
  Future<void> join() async {
    try {
      await client.api.joinRoom(id);
      final invitation = getState(EventTypes.RoomMember, client.userID);
      if (invitation != null &&
          invitation.content['is_direct'] is bool &&
          invitation.content['is_direct']) {
        await addToDirectChat(invitation.sender.id);
      }
    } on MatrixException catch (exception) {
      if (exception.errorMessage == 'No known servers') {
        await client.database?.forgetRoom(client.id, id);
        client.onRoomUpdate.add(
          RoomUpdate(
              id: id,
              membership: Membership.leave,
              notification_count: 0,
              highlight_count: 0),
        );
      }
      rethrow;
    }
  }

  /// Call the Matrix API to leave this room. If this room is set as a direct
  /// chat, this will be removed too.
  Future<void> leave() async {
    if (directChatMatrixID != '') await removeFromDirectChat();
    await client.api.leaveRoom(id);
    return;
  }

  /// Call the Matrix API to forget this room if you already left it.
  Future<void> forget() async {
    await client.database?.forgetRoom(client.id, id);
    await client.api.forgetRoom(id);
    return;
  }

  /// Call the Matrix API to kick a user from this room.
  Future<void> kick(String userID) => client.api.kickFromRoom(id, userID);

  /// Call the Matrix API to ban a user from this room.
  Future<void> ban(String userID) => client.api.banFromRoom(id, userID);

  /// Call the Matrix API to unban a banned user from this room.
  Future<void> unban(String userID) => client.api.unbanInRoom(id, userID);

  /// Set the power level of the user with the [userID] to the value [power].
  /// Returns the event ID of the new state event. If there is no known
  /// power level event, there might something broken and this returns null.
  Future<String> setPower(String userID, int power) async {
    if (states[EventTypes.RoomPowerLevels] == null) return null;
    final powerMap = <String, dynamic>{}
      ..addAll(states[EventTypes.RoomPowerLevels].content);
    if (powerMap['users'] == null) powerMap['users'] = {};
    powerMap['users'][userID] = power;

    return await client.api.sendState(
      id,
      EventTypes.RoomPowerLevels,
      powerMap,
    );
  }

  /// Call the Matrix API to invite a user to this room.
  Future<void> invite(String userID) => client.api.inviteToRoom(id, userID);

  /// Request more previous events from the server. [historyCount] defines how much events should
  /// be received maximum. When the request is answered, [onHistoryReceived] will be triggered **before**
  /// the historical events will be published in the onEvent stream.
  Future<void> requestHistory(
      {int historyCount = DefaultHistoryCount, onHistoryReceived}) async {
    final resp = await client.api.requestMessages(
      id,
      prev_batch,
      Direction.b,
      limit: historyCount,
      filter: Client.messagesFilters,
    );

    if (onHistoryReceived != null) onHistoryReceived();
    prev_batch = resp.end;

    final loadFn = () async {
      if (!((resp.chunk?.isNotEmpty ?? false) && resp.end != null)) return;

      await client.handleSync(
          SyncUpdate()
            ..rooms = (RoomsUpdate()
              ..join = {
                '$id': (JoinedRoomUpdate()
                  ..state = resp.state
                  ..timeline = (TimelineUpdate()
                    ..events = resp.chunk
                    ..prevBatch = resp.end)),
              }),
          sortAtTheEnd: true);
    };

    if (client.database != null) {
      await client.database.transaction(() async {
        await client.database.setRoomPrevBatch(resp.end, client.id, id);
        await loadFn();
        await updateSortOrder();
      });
    } else {
      await loadFn();
    }
  }

  /// Sets this room as a direct chat for this user if not already.
  Future<void> addToDirectChat(String userID) async {
    var directChats = client.directChats;
    if (directChats[userID] is List) {
      if (!directChats[userID].contains(id)) {
        directChats[userID].add(id);
      } else {
        return;
      } // Is already in direct chats
    } else {
      directChats[userID] = [id];
    }

    await client.api.setAccountData(
      client.userID,
      'm.direct',
      directChats,
    );
    return;
  }

  /// Removes this room from all direct chat tags.
  Future<void> removeFromDirectChat() async {
    var directChats = client.directChats;
    if (directChats[directChatMatrixID] is List &&
        directChats[directChatMatrixID].contains(id)) {
      directChats[directChatMatrixID].remove(id);
    } else {
      return;
    } // Nothing to do here

    await client.api.setRoomAccountData(
      client.userID,
      id,
      'm.direct',
      directChats,
    );
    return;
  }

  /// Sends *m.fully_read* and *m.read* for the given event ID.
  Future<void> sendReadReceipt(String eventID) async {
    notificationCount = 0;
    await client.database?.resetNotificationCount(client.id, id);
    await client.api.sendReadMarker(
      id,
      eventID,
      readReceiptLocationEventId: eventID,
    );
    return;
  }

  /// Returns a Room from a json String which comes normally from the store. If the
  /// state are also given, the method will await them.
  static Future<Room> getRoomFromTableRow(
    DbRoom row, // either Map<String, dynamic> or DbRoom
    Client matrix, {
    dynamic states, // DbRoomState, as iterator and optionally as future
    dynamic
        roomAccountData, // DbRoomAccountData, as iterator and optionally as future
  }) async {
    final newRoom = Room(
      id: row.roomId,
      membership: Membership.values
          .firstWhere((e) => e.toString() == 'Membership.' + row.membership),
      notificationCount: row.notificationCount,
      highlightCount: row.highlightCount,
      notificationSettings: 'mention', // TODO: do proper things
      prev_batch: row.prevBatch,
      mInvitedMemberCount: row.invitedMemberCount,
      mJoinedMemberCount: row.joinedMemberCount,
      mHeroes: row.heroes?.split(',') ?? [],
      client: matrix,
      roomAccountData: {},
      newestSortOrder: row.newestSortOrder,
      oldestSortOrder: row.oldestSortOrder,
    );

    if (states != null) {
      var rawStates;
      if (states is Future) {
        rawStates = await states;
      } else {
        rawStates = states;
      }
      for (final rawState in rawStates) {
        final newState = Event.fromDb(rawState, newRoom);
        newRoom.setState(newState);
      }
    }

    var newRoomAccountData = <String, BasicRoomEvent>{};
    if (roomAccountData != null) {
      var rawRoomAccountData;
      if (roomAccountData is Future) {
        rawRoomAccountData = await roomAccountData;
      } else {
        rawRoomAccountData = roomAccountData;
      }
      for (final singleAccountData in rawRoomAccountData) {
        final content = Event.getMapFromPayload(singleAccountData.content);
        final newData = BasicRoomEvent(
          content: content,
          type: singleAccountData.type,
          roomId: singleAccountData.roomId,
        );
        newRoomAccountData[newData.type] = newData;
      }
    }
    newRoom.roomAccountData = newRoomAccountData;

    return newRoom;
  }

  /// Creates a timeline from the store. Returns a [Timeline] object.
  Future<Timeline> getTimeline(
      {onTimelineUpdateCallback onUpdate,
      onTimelineInsertCallback onInsert}) async {
    await postLoad();
    var events;
    if (client.database != null) {
      events = await client.database.getEventList(client.id, this);
    } else {
      events = <Event>[];
    }

    // Try again to decrypt encrypted events and update the database.
    if (encrypted && client.database != null && client.encryptionEnabled) {
      await client.database.transaction(() async {
        for (var i = 0; i < events.length; i++) {
          if (events[i].type == EventTypes.Encrypted &&
              events[i].content['can_request_session'] == true) {
            events[i] = await client.encryption
                .decryptRoomEvent(id, events[i], store: true);
          }
        }
      });
    }

    var timeline = Timeline(
      room: this,
      events: events,
      onUpdate: onUpdate,
      onInsert: onInsert,
    );
    if (client.database == null) {
      prev_batch = '';
      await requestHistory(historyCount: 10);
    }
    return timeline;
  }

  /// Returns all participants for this room. With lazy loading this
  /// list may not be complete. User [requestParticipants] in this
  /// case.
  List<User> getParticipants() {
    var userList = <User>[];
    if (states[EventTypes.RoomMember] is Map<String, dynamic>) {
      for (var entry in states[EventTypes.RoomMember].entries) {
        Event state = entry.value;
        if (state.type == EventTypes.RoomMember) userList.add(state.asUser);
      }
    }
    return userList;
  }

  /// Request the full list of participants from the server. The local list
  /// from the store is not complete if the client uses lazy loading.
  Future<List<User>> requestParticipants() async {
    if (!participantListComplete && partial && client.database != null) {
      // we aren't fully loaded, maybe the users are in the database
      final users = await client.database.getUsers(client.id, this);
      for (final user in users) {
        setState(user);
      }
    }
    if (participantListComplete) return getParticipants();
    final matrixEvents = await client.api.requestMembers(id);
    final users =
        matrixEvents.map((e) => Event.fromMatrixEvent(e, this).asUser).toList();
    for (final user in users) {
      setState(user); // at *least* cache this in-memory
    }
    users.removeWhere(
        (u) => [Membership.leave, Membership.ban].contains(u.membership));
    return users;
  }

  /// Checks if the local participant list of joined and invited users is complete.
  bool get participantListComplete {
    var knownParticipants = getParticipants();
    knownParticipants.removeWhere(
        (u) => ![Membership.join, Membership.invite].contains(u.membership));
    return knownParticipants.length ==
        (mJoinedMemberCount ?? 0) + (mInvitedMemberCount ?? 0);
  }

  /// Returns the [User] object for the given [mxID] or requests it from
  /// the homeserver and waits for a response.
  Future<User> getUserByMXID(String mxID) async {
    if (states[mxID] != null) return states[mxID].asUser;
    return requestUser(mxID);
  }

  /// Returns the [User] object for the given [mxID] or requests it from
  /// the homeserver and returns a default [User] object while waiting.
  User getUserByMXIDSync(String mxID) {
    if (states[mxID] != null) {
      return states[mxID].asUser;
    } else {
      requestUser(mxID, ignoreErrors: true);
      return User(mxID, room: this);
    }
  }

  final Set<String> _requestingMatrixIds = {};

  /// Requests a missing [User] for this room. Important for clients using
  /// lazy loading. If the user can't be found this method tries to fetch
  /// the displayname and avatar from the profile if [requestProfile] is true.
  Future<User> requestUser(
    String mxID, {
    bool ignoreErrors = false,
    bool requestProfile = true,
  }) async {
    if (getState(EventTypes.RoomMember, mxID) != null) {
      return getState(EventTypes.RoomMember, mxID).asUser;
    }
    if (client.database != null) {
      // it may be in the database
      final user = await client.database.getUser(client.id, mxID, this);
      if (user != null) {
        setState(user);
        if (onUpdate != null) onUpdate.add(id);
        return user;
      }
    }
    if (mxID == null || !_requestingMatrixIds.add(mxID)) return null;
    Map<String, dynamic> resp;
    try {
      resp = await client.api.requestStateContent(
        id,
        EventTypes.RoomMember,
        mxID,
      );
    } catch (exception) {
      if (!ignoreErrors) {
        _requestingMatrixIds.remove(mxID);
        rethrow;
      }
    }
    if (resp == null && requestProfile) {
      try {
        final profile = await client.api.requestProfile(mxID);
        resp = {
          'displayname': profile.displayname,
          'avatar_url': profile.avatarUrl,
        };
      } catch (exception) {
        _requestingMatrixIds.remove(mxID);
        if (!ignoreErrors) rethrow;
      }
    }
    if (resp == null) {
      return null;
    }
    final user = User(mxID,
        displayName: resp['displayname'],
        avatarUrl: resp['avatar_url'],
        room: this);
    states[mxID] = user;
    await client.database?.transaction(() async {
      final content = <String, dynamic>{
        'sender': mxID,
        'type': EventTypes.RoomMember,
        'content': resp,
        'state_key': mxID,
      };
      await client.database.storeEventUpdate(
        client.id,
        EventUpdate(
            content: content,
            roomID: id,
            type: 'state',
            eventType: EventTypes.RoomMember,
            sortOrder: 0.0),
      );
    });
    if (onUpdate != null) onUpdate.add(id);
    _requestingMatrixIds.remove(mxID);
    return user;
  }

  /// Searches for the event on the server. Returns null if not found.
  Future<Event> getEventById(String eventID) async {
    final matrixEvent = await client.api.requestEvent(id, eventID);
    return Event.fromMatrixEvent(matrixEvent, this);
  }

  /// Returns the power level of the given user ID.
  int getPowerLevelByUserId(String userId) {
    var powerLevel = 0;
    Event powerLevelState = states[EventTypes.RoomPowerLevels];
    if (powerLevelState == null) return powerLevel;
    if (powerLevelState.content['users_default'] is int) {
      powerLevel = powerLevelState.content['users_default'];
    }
    if (powerLevelState.content['users'] is Map<String, dynamic> &&
        powerLevelState.content['users'][userId] != null) {
      powerLevel = powerLevelState.content['users'][userId];
    }
    return powerLevel;
  }

  /// Returns the user's own power level.
  int get ownPowerLevel => getPowerLevelByUserId(client.userID);

  /// Returns the power levels from all users for this room or null if not given.
  Map<String, int> get powerLevels {
    Event powerLevelState = states[EventTypes.RoomPowerLevels];
    if (powerLevelState.content['users'] is Map<String, int>) {
      return powerLevelState.content['users'];
    }
    return null;
  }

  /// Uploads a new user avatar for this room. Returns the event ID of the new
  /// m.room.avatar event.
  Future<String> setAvatar(MatrixFile file) async {
    final uploadResp = await client.api.upload(file.bytes, file.name);
    return await client.api.sendState(
      id,
      EventTypes.RoomAvatar,
      {'url': uploadResp},
    );
  }

  bool _hasPermissionFor(String action) {
    if (getState(EventTypes.RoomPowerLevels) == null ||
        getState(EventTypes.RoomPowerLevels).content[action] == null) {
      return true;
    }
    return ownPowerLevel >=
        getState(EventTypes.RoomPowerLevels).content[action];
  }

  /// The level required to ban a user.
  bool get canBan => _hasPermissionFor('ban');

  /// The default level required to send message events. Can be overridden by the events key.
  bool get canSendDefaultMessages => _hasPermissionFor('events_default');

  /// The level required to invite a user.
  bool get canInvite => _hasPermissionFor('invite');

  /// The level required to kick a user.
  bool get canKick => _hasPermissionFor('kick');

  /// The level required to redact an event.
  bool get canRedact => _hasPermissionFor('redact');

  ///  	The default level required to send state events. Can be overridden by the events key.
  bool get canSendDefaultStates => _hasPermissionFor('state_default');

  bool get canChangePowerLevel => canSendEvent(EventTypes.RoomPowerLevels);

  bool canSendEvent(String eventType) {
    if (getState(EventTypes.RoomPowerLevels) == null) return true;
    if (getState(EventTypes.RoomPowerLevels).content['events'] == null ||
        getState(EventTypes.RoomPowerLevels).content['events'][eventType] ==
            null) {
      return eventType == EventTypes.Message
          ? canSendDefaultMessages
          : canSendDefaultStates;
    }
    return ownPowerLevel >=
        getState(EventTypes.RoomPowerLevels).content['events'][eventType];
  }

  /// Returns the [PushRuleState] for this room, based on the m.push_rules stored in
  /// the account_data.
  PushRuleState get pushRuleState {
    if (!client.accountData.containsKey('m.push_rules') ||
        !(client.accountData['m.push_rules'].content['global'] is Map)) {
      return PushRuleState.notify;
    }
    final Map<String, dynamic> globalPushRules =
        client.accountData['m.push_rules'].content['global'];
    if (globalPushRules == null) return PushRuleState.notify;

    if (globalPushRules['override'] is List) {
      for (var i = 0; i < globalPushRules['override'].length; i++) {
        if (globalPushRules['override'][i]['rule_id'] == id) {
          if (globalPushRules['override'][i]['actions']
                  .indexOf('dont_notify') !=
              -1) {
            return PushRuleState.dont_notify;
          }
          break;
        }
      }
    }

    if (globalPushRules['room'] is List) {
      for (var i = 0; i < globalPushRules['room'].length; i++) {
        if (globalPushRules['room'][i]['rule_id'] == id) {
          if (globalPushRules['room'][i]['actions'].indexOf('dont_notify') !=
              -1) {
            return PushRuleState.mentions_only;
          }
          break;
        }
      }
    }

    return PushRuleState.notify;
  }

  /// Sends a request to the homeserver to set the [PushRuleState] for this room.
  /// Returns ErrorResponse if something goes wrong.
  Future<void> setPushRuleState(PushRuleState newState) async {
    if (newState == pushRuleState) return null;
    dynamic resp;
    switch (newState) {
      // All push notifications should be sent to the user
      case PushRuleState.notify:
        if (pushRuleState == PushRuleState.dont_notify) {
          await client.api.deletePushRule('global', PushRuleKind.override, id);
        } else if (pushRuleState == PushRuleState.mentions_only) {
          await client.api.deletePushRule('global', PushRuleKind.room, id);
        }
        break;
      // Only when someone mentions the user, a push notification should be sent
      case PushRuleState.mentions_only:
        if (pushRuleState == PushRuleState.dont_notify) {
          await client.api.deletePushRule('global', PushRuleKind.override, id);
          await client.api.setPushRule(
            'global',
            PushRuleKind.room,
            id,
            [PushRuleAction.dont_notify],
          );
        } else if (pushRuleState == PushRuleState.notify) {
          await client.api.setPushRule(
            'global',
            PushRuleKind.room,
            id,
            [PushRuleAction.dont_notify],
          );
        }
        break;
      // No push notification should be ever sent for this room.
      case PushRuleState.dont_notify:
        if (pushRuleState == PushRuleState.mentions_only) {
          await client.api.deletePushRule('global', PushRuleKind.room, id);
        }
        await client.api.setPushRule(
          'global',
          PushRuleKind.override,
          id,
          [PushRuleAction.dont_notify],
          conditions: [
            PushConditions('event_match', key: 'room_id', pattern: id)
          ],
        );
    }
    return resp;
  }

  /// Redacts this event. Returns [ErrorResponse] on error.
  Future<String> redactEvent(String eventId,
      {String reason, String txid}) async {
    // Create new transaction id
    String messageID;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (txid == null) {
      messageID = 'msg$now';
    } else {
      messageID = txid;
    }
    var data = <String, dynamic>{};
    if (reason != null) data['reason'] = reason;
    return await client.api.redact(
      id,
      eventId,
      messageID,
      reason: reason,
    );
  }

  Future<void> sendTypingInfo(bool isTyping, {int timeout}) {
    var data = <String, dynamic>{
      'typing': isTyping,
    };
    if (timeout != null) data['timeout'] = timeout;
    return client.api.sendTypingNotification(client.userID, id, isTyping);
  }

  /// This is sent by the caller when they wish to establish a call.
  /// [callId] is a unique identifier for the call.
  /// [version] is the version of the VoIP specification this message adheres to. This specification is version 0.
  /// [lifetime] is the time in milliseconds that the invite is valid for. Once the invite age exceeds this value,
  /// clients should discard it. They should also no longer show the call as awaiting an answer in the UI.
  /// [type] The type of session description. Must be 'offer'.
  /// [sdp] The SDP text of the session description.
  Future<String> inviteToCall(String callId, int lifetime, String sdp,
      {String type = 'offer', int version = 0, String txid}) async {
    txid ??= 'txid${DateTime.now().millisecondsSinceEpoch}';

    return await client.api.sendMessage(
      id,
      EventTypes.CallInvite,
      txid,
      {
        'call_id': callId,
        'lifetime': lifetime,
        'offer': {'sdp': sdp, 'type': type},
        'version': version,
      },
    );
  }

  /// This is sent by callers after sending an invite and by the callee after answering.
  /// Its purpose is to give the other party additional ICE candidates to try using to communicate.
  ///
  /// [callId] The ID of the call this event relates to.
  ///
  /// [version] The version of the VoIP specification this messages adheres to. This specification is version 0.
  ///
  /// [candidates] Array of objects describing the candidates. Example:
  ///
  /// ```
  /// [
  ///       {
  ///           "candidate": "candidate:863018703 1 udp 2122260223 10.9.64.156 43670 typ host generation 0",
  ///           "sdpMLineIndex": 0,
  ///           "sdpMid": "audio"
  ///       }
  ///   ],
  /// ```
  Future<String> sendCallCandidates(
    String callId,
    List<Map<String, dynamic>> candidates, {
    int version = 0,
    String txid,
  }) async {
    txid ??= 'txid${DateTime.now().millisecondsSinceEpoch}';
    return await client.api.sendMessage(
      id,
      EventTypes.CallCandidates,
      txid,
      {
        'call_id': callId,
        'candidates': candidates,
        'version': version,
      },
    );
  }

  /// This event is sent by the callee when they wish to answer the call.
  /// [callId] is a unique identifier for the call.
  /// [version] is the version of the VoIP specification this message adheres to. This specification is version 0.
  /// [type] The type of session description. Must be 'answer'.
  /// [sdp] The SDP text of the session description.
  Future<String> answerCall(String callId, String sdp,
      {String type = 'answer', int version = 0, String txid}) async {
    txid ??= 'txid${DateTime.now().millisecondsSinceEpoch}';
    return await client.api.sendMessage(
      id,
      EventTypes.CallAnswer,
      txid,
      {
        'call_id': callId,
        'answer': {'sdp': sdp, 'type': type},
        'version': version,
      },
    );
  }

  /// This event is sent by the callee when they wish to answer the call.
  /// [callId] The ID of the call this event relates to.
  /// [version] is the version of the VoIP specification this message adheres to. This specification is version 0.
  Future<String> hangupCall(String callId,
      {int version = 0, String txid}) async {
    txid ??= 'txid${DateTime.now().millisecondsSinceEpoch}';
    return await client.api.sendMessage(
      id,
      EventTypes.CallHangup,
      txid,
      {
        'call_id': callId,
        'version': version,
      },
    );
  }

  /// Returns all aliases for this room.
  List<String> get aliases {
    var aliases = <String>[];
    for (var aliasEvent in states.states[EventTypes.RoomAliases].values) {
      if (aliasEvent.content['aliases'] is List) {
        aliases.addAll(aliasEvent.content['aliases']);
      }
    }
    return aliases;
  }

  /// A room may be public meaning anyone can join the room without any prior action. Alternatively,
  /// it can be invite meaning that a user who wishes to join the room must first receive an invite
  /// to the room from someone already inside of the room. Currently, knock and private are reserved
  /// keywords which are not implemented.
  JoinRules get joinRules => getState(EventTypes.RoomJoinRules) != null
      ? JoinRules.values.firstWhere(
          (r) =>
              r.toString().replaceAll('JoinRules.', '') ==
              getState(EventTypes.RoomJoinRules).content['join_rule'],
          orElse: () => null)
      : null;

  /// Changes the join rules. You should check first if the user is able to change it.
  Future<void> setJoinRules(JoinRules joinRules) async {
    await client.api.sendState(
      id,
      EventTypes.RoomJoinRules,
      {
        'join_rule': joinRules.toString().replaceAll('JoinRules.', ''),
      },
    );
    return;
  }

  /// Whether the user has the permission to change the join rules.
  bool get canChangeJoinRules => canSendEvent(EventTypes.RoomJoinRules);

  /// This event controls whether guest users are allowed to join rooms. If this event
  /// is absent, servers should act as if it is present and has the guest_access value "forbidden".
  GuestAccess get guestAccess => getState(EventTypes.GuestAccess) != null
      ? GuestAccess.values.firstWhere(
          (r) =>
              r.toString().replaceAll('GuestAccess.', '') ==
              getState(EventTypes.GuestAccess).content['guest_access'],
          orElse: () => GuestAccess.forbidden)
      : GuestAccess.forbidden;

  /// Changes the guest access. You should check first if the user is able to change it.
  Future<void> setGuestAccess(GuestAccess guestAccess) async {
    await client.api.sendState(
      id,
      EventTypes.GuestAccess,
      {
        'guest_access': guestAccess.toString().replaceAll('GuestAccess.', ''),
      },
    );
    return;
  }

  /// Whether the user has the permission to change the guest access.
  bool get canChangeGuestAccess => canSendEvent(EventTypes.GuestAccess);

  /// This event controls whether a user can see the events that happened in a room from before they joined.
  HistoryVisibility get historyVisibility =>
      getState(EventTypes.HistoryVisibility) != null
          ? HistoryVisibility.values.firstWhere(
              (r) =>
                  r.toString().replaceAll('HistoryVisibility.', '') ==
                  getState(EventTypes.HistoryVisibility)
                      .content['history_visibility'],
              orElse: () => null)
          : null;

  /// Changes the history visibility. You should check first if the user is able to change it.
  Future<void> setHistoryVisibility(HistoryVisibility historyVisibility) async {
    await client.api.sendState(
      id,
      EventTypes.HistoryVisibility,
      {
        'history_visibility':
            historyVisibility.toString().replaceAll('HistoryVisibility.', ''),
      },
    );
    return;
  }

  /// Whether the user has the permission to change the history visibility.
  bool get canChangeHistoryVisibility =>
      canSendEvent(EventTypes.HistoryVisibility);

  /// Returns the encryption algorithm. Currently only `m.megolm.v1.aes-sha2` is supported.
  /// Returns null if there is no encryption algorithm.
  String get encryptionAlgorithm => getState(EventTypes.Encryption) != null
      ? getState(EventTypes.Encryption).content['algorithm'].toString()
      : null;

  /// Checks if this room is encrypted.
  bool get encrypted => encryptionAlgorithm != null;

  Future<void> enableEncryption({int algorithmIndex = 0}) async {
    if (encrypted) throw ('Encryption is already enabled!');
    final algorithm = Client.supportedGroupEncryptionAlgorithms[algorithmIndex];
    await client.api.sendState(
      id,
      EventTypes.Encryption,
      {
        'algorithm': algorithm,
      },
    );
    return;
  }

  /// Returns all known device keys for all participants in this room.
  Future<List<DeviceKeys>> getUserDeviceKeys() async {
    var deviceKeys = <DeviceKeys>[];
    var users = await requestParticipants();
    for (final user in users) {
      if (client.userDeviceKeys.containsKey(user.id)) {
        for (var deviceKeyEntry
            in client.userDeviceKeys[user.id].deviceKeys.values) {
          deviceKeys.add(deviceKeyEntry);
        }
      }
    }
    return deviceKeys;
  }

  Future<void> requestSessionKey(String sessionId, String senderKey) async {
    if (!client.encryptionEnabled) {
      return;
    }
    await client.encryption.keyManager.request(this, sessionId, senderKey);
  }
}
