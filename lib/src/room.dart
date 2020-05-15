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

import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/src/client.dart';
import 'package:famedlysdk/src/event.dart';
import 'package:famedlysdk/src/room_account_data.dart';
import 'package:famedlysdk/src/sync/event_update.dart';
import 'package:famedlysdk/src/sync/room_update.dart';
import 'package:famedlysdk/src/utils/matrix_exception.dart';
import 'package:famedlysdk/src/utils/matrix_file.dart';
import 'package:famedlysdk/src/utils/session_key.dart';
import 'package:image/image.dart';
import 'package:matrix_file_e2ee/matrix_file_e2ee.dart';
import 'package:mime_type/mime_type.dart';
import 'package:olm/olm.dart' as olm;
import 'package:html_unescape/html_unescape.dart';

import './user.dart';
import 'timeline.dart';
import 'utils/matrix_localizations.dart';
import 'utils/states_map.dart';
import './utils/markdown.dart';

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
  Map<String, RoomAccountData> ephemerals = {};

  /// Key-Value store for private account data only visible for this user.
  Map<String, RoomAccountData> roomAccountData = {};

  olm.OutboundGroupSession get outboundGroupSession => _outboundGroupSession;
  olm.OutboundGroupSession _outboundGroupSession;

  List<String> _outboundGroupSessionDevices;

  /// Clears the existing outboundGroupSession, tries to create a new one and
  /// stores it as an ingoingGroupSession in the [sessionKeys]. Then sends the
  /// new session encrypted with olm to all non-blocked devices using
  /// to-device-messaging.
  Future<void> createOutboundGroupSession() async {
    await clearOutboundGroupSession(wipe: true);
    var deviceKeys = await getUserDeviceKeys();
    olm.OutboundGroupSession outboundGroupSession;
    var outboundGroupSessionDevices = <String>[];
    for (var keys in deviceKeys) {
      if (!keys.blocked) outboundGroupSessionDevices.add(keys.deviceId);
    }
    outboundGroupSessionDevices.sort();
    try {
      outboundGroupSession = olm.OutboundGroupSession();
      outboundGroupSession.create();
    } catch (e) {
      outboundGroupSession = null;
      print('[LibOlm] Unable to create new outboundGroupSession: ' +
          e.toString());
    }

    if (outboundGroupSession == null) return;
    // Add as an inboundSession to the [sessionKeys].
    var rawSession = <String, dynamic>{
      'algorithm': 'm.megolm.v1.aes-sha2',
      'room_id': id,
      'session_id': outboundGroupSession.session_id(),
      'session_key': outboundGroupSession.session_key(),
    };
    setSessionKey(rawSession['session_id'], rawSession);
    try {
      await client.sendToDevice(deviceKeys, 'm.room_key', rawSession);
      _outboundGroupSession = outboundGroupSession;
      _outboundGroupSessionDevices = outboundGroupSessionDevices;
      await _storeOutboundGroupSession();
    } catch (e) {
      print(
          '[LibOlm] Unable to send the session key to the participating devices: ' +
              e.toString());
      await clearOutboundGroupSession();
    }
    return;
  }

  Future<void> _storeOutboundGroupSession() async {
    if (_outboundGroupSession == null) return;
    await client.storeAPI?.setItem(
        '/clients/${client.deviceID}/rooms/${id}/outbound_group_session',
        _outboundGroupSession.pickle(client.userID));
    await client.storeAPI?.setItem(
        '/clients/${client.deviceID}/rooms/${id}/outbound_group_session_devices',
        json.encode(_outboundGroupSessionDevices));
    return;
  }

  /// Clears the existing outboundGroupSession but first checks if the participating
  /// devices have been changed. Returns false if the session has not been cleared because
  /// it wasn't necessary.
  Future<bool> clearOutboundGroupSession({bool wipe = false}) async {
    if (!wipe && _outboundGroupSessionDevices != null) {
      var deviceKeys = await getUserDeviceKeys();
      var outboundGroupSessionDevices = <String>[];
      for (var keys in deviceKeys) {
        if (!keys.blocked) outboundGroupSessionDevices.add(keys.deviceId);
      }
      outboundGroupSessionDevices.sort();
      if (outboundGroupSessionDevices.toString() ==
          _outboundGroupSessionDevices.toString()) {
        return false;
      }
    }
    _outboundGroupSessionDevices == null;
    await client.storeAPI?.setItem(
        '/clients/${client.deviceID}/rooms/${id}/outbound_group_session', null);
    await client.storeAPI?.setItem(
        '/clients/${client.deviceID}/rooms/${id}/outbound_group_session_devices',
        null);
    _outboundGroupSession?.free();
    _outboundGroupSession = null;
    return true;
  }

  /// Key-Value store of session ids to the session keys. Only m.megolm.v1.aes-sha2
  /// session keys are supported. They are stored as a Map with the following keys:
  /// {
  ///   "algorithm": "m.megolm.v1.aes-sha2",
  ///   "room_id": "!Cuyf34gef24t:localhost",
  ///   "session_id": "X3lUlvLELLYxeTx4yOVu6UDpasGEVO0Jbu+QFnm0cKQ",
  ///   "session_key": "AgAAAADxKHa9uFxcXzwYoNueL5Xqi69IkD4sni8LlfJL7qNBEY..."
  /// }
  Map<String, SessionKey> get sessionKeys => _sessionKeys;
  Map<String, SessionKey> _sessionKeys = {};

  /// Add a new session key to the [sessionKeys].
  void setSessionKey(String sessionId, Map<String, dynamic> content,
      {bool forwarded = false}) {
    if (sessionKeys.containsKey(sessionId)) return;
    olm.InboundGroupSession inboundGroupSession;
    if (content['algorithm'] == 'm.megolm.v1.aes-sha2') {
      try {
        inboundGroupSession = olm.InboundGroupSession();
        if (forwarded) {
          inboundGroupSession.import_session(content['session_key']);
        } else {
          inboundGroupSession.create(content['session_key']);
        }
      } catch (e) {
        inboundGroupSession = null;
        print('[LibOlm] Could not create new InboundGroupSession: ' +
            e.toString());
      }
    }
    _sessionKeys[sessionId] = SessionKey(
      content: content,
      inboundGroupSession: inboundGroupSession,
      indexes: {},
      key: client.userID,
    );
    if (_fullyRestored) {
      client.storeAPI?.setItem(
          '/clients/${client.deviceID}/rooms/${id}/session_keys',
          json.encode(sessionKeys));
    }
    _tryAgainDecryptLastMessage();
    onSessionKeyReceived.add(sessionId);
  }

  void _tryAgainDecryptLastMessage() {
    if (getState('m.room.encrypted') != null) {
      final decrypted = getState('m.room.encrypted').decrypted;
      if (decrypted.type != EventTypes.Encrypted) {
        setState(decrypted);
      }
    }
  }

  /// Returns the [Event] for the given [typeKey] and optional [stateKey].
  /// If no [stateKey] is provided, it defaults to an empty string.
  Event getState(String typeKey, [String stateKey = '']) =>
      states.states[typeKey] != null ? states.states[typeKey][stateKey] : null;

  /// Adds the [state] to this room and overwrites a state with the same
  /// typeKey/stateKey key pair if there is one.
  void setState(Event state) {
    // Decrypt if necessary
    if (state.type == EventTypes.Encrypted) {
      try {
        state = decryptGroupMessage(state);
      } catch (e) {
        print('[LibOlm] Could not decrypt room state: ' + e.toString());
      }
    }
    // Check if this is a member change and we need to clear the outboundGroupSession.
    if (encrypted &&
        outboundGroupSession != null &&
        state.type == EventTypes.RoomMember) {
      var newUser = state.asUser;
      var oldUser = getState('m.room.member', newUser.id)?.asUser;
      if (oldUser == null || oldUser.membership != newUser.membership) {
        clearOutboundGroupSession();
      }
    }
    if ((getState(state.typeKey)?.time?.millisecondsSinceEpoch ?? 0) >
        (state.time?.millisecondsSinceEpoch ?? 1)) {
      return;
    }
    if (!states.states.containsKey(state.typeKey)) {
      states.states[state.typeKey] = {};
    }
    states.states[state.typeKey][state.stateKey ?? ''] = state;
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
  String get name => states['m.room.name'] != null
      ? states['m.room.name'].content['name']
      : '';

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
  String get topic => states['m.room.topic'] != null
      ? states['m.room.topic'].content['topic']
      : '';

  /// The avatar of the room if set by a participant.
  Uri get avatar {
    if (states['m.room.avatar'] != null &&
        states['m.room.avatar'].content['url'] != null) {
      return Uri.parse(states['m.room.avatar'].content['url']);
    }
    if (mHeroes != null && mHeroes.length == 1 && states[mHeroes[0]] != null) {
      return states[mHeroes[0]].asUser.avatarUrl;
    }
    if (membership == Membership.invite &&
        getState('m.room.member', client.userID) != null) {
      return getState('m.room.member', client.userID).sender.avatarUrl;
    }
    return null;
  }

  /// The address in the format: #roomname:homeserver.org.
  String get canonicalAlias => states['m.room.canonical_alias'] != null
      ? states['m.room.canonical_alias'].content['alias']
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
    var lastTime = DateTime.fromMillisecondsSinceEpoch(0);
    var lastEvent = getState('m.room.message');
    if (lastEvent == null) {
      states.forEach((final String key, final entry) {
        if (!entry.containsKey('')) return;
        final Event state = entry[''];
        if (state.time != null &&
            state.time.millisecondsSinceEpoch >
                lastTime.millisecondsSinceEpoch) {
          lastTime = state.time;
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
  });

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
      if (states['m.room.member'] is Map<String, dynamic>) {
        for (var entry in states['m.room.member'].entries) {
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
        getState('m.room.member', client.userID) != null) {
      return getState('m.room.member', client.userID).sender.calcDisplayname();
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
      return lastEvent.time;
    }
    return DateTime.now();
  }

  /// Call the Matrix API to change the name of this room. Returns the event ID of the
  /// new m.room.name event.
  Future<String> setName(String newName) async {
    final resp = await client.jsonRequest(
        type: HTTPType.PUT,
        action: '/client/r0/rooms/${id}/state/m.room.name',
        data: {'name': newName});
    return resp['event_id'];
  }

  /// Call the Matrix API to change the topic of this room.
  Future<String> setDescription(String newName) async {
    final resp = await client.jsonRequest(
        type: HTTPType.PUT,
        action: '/client/r0/rooms/${id}/state/m.room.topic',
        data: {'topic': newName});
    return resp['event_id'];
  }

  /// Sends a normal text message to this room. Returns the event ID generated
  /// by the server for this message.
  Future<String> sendTextEvent(String message, {String txid, Event inReplyTo, bool parseMarkdown = true}) {
    final event = <String, dynamic>{
      'msgtype': 'm.text',
      'body': message,
    };
    if (message.startsWith('/me ')) {
      event['msgtype'] = 'm.emote';
      event['body'] = message.substring(4);
    }
    if (parseMarkdown) {
      // load the emote packs
      final emotePacks = <String, Map<String, String>>{};
      final addEmotePack = (String packName, Map<String, dynamic> content) {
        emotePacks[packName] = <String, String>{};
        content.forEach((key, value) {
          if (key is String && value is String && value.startsWith('mxc://')) {
            emotePacks[packName][key] = value;
          }
        });
      };
      final roomEmotes = getState('im.ponies.room_emotes');
      final userEmotes = client.accountData['im.ponies.user_emotes'];
      if (roomEmotes != null && roomEmotes.content['short'] is Map) {
        addEmotePack('room', roomEmotes.content['short']);
      }
      if (userEmotes != null && userEmotes.content['short'] is Map) {
        addEmotePack('user', userEmotes.content['short']);
      }
      final html = markdown(event['body'], emotePacks);
      // if the decoded html is the same as the body, there is no need in sending a formatted message
      if (HtmlUnescape().convert(html) != event['body']) {
        event['format'] = 'org.matrix.custom.html';
        event['formatted_body'] = html;
      }
    }
    return sendEvent(event, txid: txid, inReplyTo: inReplyTo);
  }

  /// Sends a [file] to this room after uploading it. The [msgType] is optional
  /// and will be detected by the mimetype of the file. Returns the mxc uri of
  /// the uploaded file. If [waitUntilSent] is true, the future will wait until
  /// the message event has received the server. Otherwise the future will only
  /// wait until the file has been uploaded.
  Future<String> sendFileEvent(
    MatrixFile file, {
    String msgType,
    String txid,
    Event inReplyTo,
    Map<String, dynamic> info,
    bool waitUntilSent = false,
    MatrixFile thumbnail,
  }) async {
    Image fileImage;
    Image thumbnailImage;
    EncryptedFile encryptedThumbnail;
    String thumbnailUploadResp;

    var fileName = file.path.split('/').last;
    final mimeType = mime(file.path) ?? '';
    if (msgType == null) {
      final metaType = (mimeType).split('/')[0];
      switch (metaType) {
        case 'image':
        case 'audio':
        case 'video':
          msgType = 'm.$metaType';
          break;
        default:
          msgType = 'm.file';
          break;
      }
    }

    if (msgType == 'm.image') {
      fileImage = decodeImage(file.bytes.toList());
      if (thumbnail != null) {
        thumbnailImage = decodeImage(thumbnail.bytes.toList());
      }
    }

    final sendEncrypted = encrypted && client.fileEncryptionEnabled;
    EncryptedFile encryptedFile;
    if (sendEncrypted) {
      encryptedFile = await file.encrypt();
      if (thumbnail != null) {
        encryptedThumbnail = await thumbnail.encrypt();
      }
    }
    final uploadResp = await client.upload(
      file,
      contentType: sendEncrypted ? 'application/octet-stream' : null,
    );
    if (thumbnail != null) {
      thumbnailUploadResp = await client.upload(
        thumbnail,
        contentType: sendEncrypted ? 'application/octet-stream' : null,
      );
    }

    // Send event
    var content = <String, dynamic>{
      'msgtype': msgType,
      'body': fileName,
      'filename': fileName,
      if (!sendEncrypted) 'url': uploadResp,
      if (sendEncrypted)
        'file': {
          'url': uploadResp,
          'mimetype': mimeType,
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
      'info': info ??
          {
            'mimetype': mimeType,
            'size': file.size,
            if (fileImage != null) 'h': fileImage.height,
            if (fileImage != null) 'w': fileImage.width,
            if (thumbnailUploadResp != null && !sendEncrypted)
              'thumbnail_url': thumbnailUploadResp,
            if (thumbnailUploadResp != null && sendEncrypted)
              'thumbnail_file': {
                'url': thumbnailUploadResp,
                'mimetype': mimeType,
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
            if (thumbnailImage != null)
              'thumbnail_info': {
                'h': thumbnailImage.height,
                'mimetype': mimeType,
                'size': thumbnail.size,
                'w': thumbnailImage.width,
              }
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

  /// Sends an audio file to this room and returns the mxc uri.
  Future<String> sendAudioEvent(MatrixFile file,
      {String txid, Event inReplyTo}) async {
    return await sendFileEvent(file,
        msgType: 'm.audio', txid: txid, inReplyTo: inReplyTo);
  }

  /// Sends an image to this room and returns the mxc uri.
  Future<String> sendImageEvent(MatrixFile file,
      {String txid, int width, int height, Event inReplyTo}) async {
    return await sendFileEvent(file,
        msgType: 'm.image',
        txid: txid,
        inReplyTo: inReplyTo,
        info: {
          'size': file.size,
          'mimetype': mime(file.path.split('/').last),
          'w': width,
          'h': height,
        });
  }

  /// Sends an video to this room and returns the mxc uri.
  Future<String> sendVideoEvent(MatrixFile file,
      {String txid,
      int videoWidth,
      int videoHeight,
      int duration,
      MatrixFile thumbnail,
      int thumbnailWidth,
      int thumbnailHeight,
      Event inReplyTo}) async {
    var fileName = file.path.split('/').last;
    var info = <String, dynamic>{
      'size': file.size,
      'mimetype': mime(fileName),
    };
    if (videoWidth != null) {
      info['w'] = videoWidth;
    }
    if (thumbnailHeight != null) {
      info['h'] = thumbnailHeight;
    }
    if (duration != null) {
      info['duration'] = duration;
    }
    if (thumbnail != null && !(encrypted && client.encryptionEnabled)) {
      var thumbnailName = file.path.split('/').last;
      final thumbnailUploadResp = await client.upload(thumbnail);
      info['thumbnail_url'] = thumbnailUploadResp;
      info['thumbnail_info'] = {
        'size': thumbnail.size,
        'mimetype': mime(thumbnailName),
      };
      if (thumbnailWidth != null) {
        info['thumbnail_info']['w'] = thumbnailWidth;
      }
      if (thumbnailHeight != null) {
        info['thumbnail_info']['h'] = thumbnailHeight;
      }
    }

    return await sendFileEvent(
      file,
      msgType: 'm.video',
      txid: txid,
      inReplyTo: inReplyTo,
      info: info,
    );
  }

  /// Sends an event to this room with this json as a content. Returns the
  /// event ID generated from the server.
  Future<String> sendEvent(Map<String, dynamic> content,
      {String txid, Event inReplyTo}) async {
    final type = 'm.room.message';
    final sendType =
        (encrypted && client.encryptionEnabled) ? 'm.room.encrypted' : type;

    // Create new transaction id
    String messageID;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (txid == null) {
      messageID = 'msg$now';
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

    // Display a *sending* event and store it.
    var eventUpdate =
        EventUpdate(type: 'timeline', roomID: id, eventType: type, content: {
      'type': type,
      'event_id': messageID,
      'sender': client.userID,
      'status': 0,
      'origin_server_ts': now,
      'content': content
    });
    client.onEvent.add(eventUpdate);
    await client.store?.transaction(() {
      client.store.storeEventUpdate(eventUpdate);
      return;
    });

    // Send the text and on success, store and display a *sent* event.
    try {
      final response = await client.jsonRequest(
          type: HTTPType.PUT,
          action: '/client/r0/rooms/${id}/send/$sendType/$messageID',
          data: client.encryptionEnabled
              ? await encryptGroupMessagePayload(content)
              : content);
      final String res = response['event_id'];
      eventUpdate.content['status'] = 1;
      eventUpdate.content['unsigned'] = {'transaction_id': messageID};
      eventUpdate.content['event_id'] = res;
      client.onEvent.add(eventUpdate);
      await client.store?.transaction(() {
        client.store.storeEventUpdate(eventUpdate);
        return;
      });
      return res;
    } catch (exception) {
      print('[Client] Error while sending: ' + exception.toString());
      // On error, set status to -1
      eventUpdate.content['status'] = -1;
      eventUpdate.content['unsigned'] = {'transaction_id': messageID};
      client.onEvent.add(eventUpdate);
      await client.store?.transaction(() {
        client.store.storeEventUpdate(eventUpdate);
        return;
      });
    }
    return null;
  }

  /// Call the Matrix API to join this room if the user is not already a member.
  /// If this room is intended to be a direct chat, the direct chat flag will
  /// automatically be set.
  Future<void> join() async {
    try {
      await client.jsonRequest(
          type: HTTPType.POST, action: '/client/r0/rooms/${id}/join');
      final invitation = getState('m.room.member', client.userID);
      if (invitation != null &&
          invitation.content['is_direct'] is bool &&
          invitation.content['is_direct']) {
        await addToDirectChat(invitation.sender.id);
      }
    } on MatrixException catch (exception) {
      if (exception.errorMessage == 'No known servers') {
        await client.store?.forgetRoom(id);
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
    await client.jsonRequest(
        type: HTTPType.POST, action: '/client/r0/rooms/${id}/leave');
    return;
  }

  /// Call the Matrix API to forget this room if you already left it.
  Future<void> forget() async {
    await client.store?.forgetRoom(id);
    await client.jsonRequest(
        type: HTTPType.POST, action: '/client/r0/rooms/${id}/forget');
    return;
  }

  /// Call the Matrix API to kick a user from this room.
  Future<void> kick(String userID) async {
    await client.jsonRequest(
        type: HTTPType.POST,
        action: '/client/r0/rooms/${id}/kick',
        data: {'user_id': userID});
    return;
  }

  /// Call the Matrix API to ban a user from this room.
  Future<void> ban(String userID) async {
    await client.jsonRequest(
        type: HTTPType.POST,
        action: '/client/r0/rooms/${id}/ban',
        data: {'user_id': userID});
    return;
  }

  /// Call the Matrix API to unban a banned user from this room.
  Future<void> unban(String userID) async {
    await client.jsonRequest(
        type: HTTPType.POST,
        action: '/client/r0/rooms/${id}/unban',
        data: {'user_id': userID});
    return;
  }

  /// Set the power level of the user with the [userID] to the value [power].
  /// Returns the event ID of the new state event. If there is no known
  /// power level event, there might something broken and this returns null.
  Future<String> setPower(String userID, int power) async {
    if (states['m.room.power_levels'] == null) return null;
    var powerMap = {}..addAll(states['m.room.power_levels'].content);
    if (powerMap['users'] == null) powerMap['users'] = {};
    powerMap['users'][userID] = power;

    final resp = await client.jsonRequest(
        type: HTTPType.PUT,
        action: '/client/r0/rooms/$id/state/m.room.power_levels',
        data: powerMap);
    return resp['event_id'];
  }

  /// Call the Matrix API to invite a user to this room.
  Future<void> invite(String userID) async {
    await client.jsonRequest(
        type: HTTPType.POST,
        action: '/client/r0/rooms/${id}/invite',
        data: {'user_id': userID});
    return;
  }

  /// Request more previous events from the server. [historyCount] defines how much events should
  /// be received maximum. When the request is answered, [onHistoryReceived] will be triggered **before**
  /// the historical events will be published in the onEvent stream.
  Future<void> requestHistory(
      {int historyCount = DefaultHistoryCount, onHistoryReceived}) async {
    final dynamic resp = await client.jsonRequest(
        type: HTTPType.GET,
        action:
            '/client/r0/rooms/$id/messages?from=${prev_batch}&dir=b&limit=$historyCount&filter=${Client.messagesFilters}');

    if (onHistoryReceived != null) onHistoryReceived();
    prev_batch = resp['end'];
    await client.store?.storeRoomPrevBatch(this);

    if (!(resp['chunk'] is List<dynamic> &&
        resp['chunk'].length > 0 &&
        resp['end'] is String)) return;

    if (resp['state'] is List<dynamic>) {
      await client.store?.transaction(() {
        for (var i = 0; i < resp['state'].length; i++) {
          var eventUpdate = EventUpdate(
            type: 'state',
            roomID: id,
            eventType: resp['state'][i]['type'],
            content: resp['state'][i],
          ).decrypt(this);
          client.onEvent.add(eventUpdate);
          client.store.storeEventUpdate(eventUpdate);
        }
        return;
      });
      if (client.store == null) {
        for (var i = 0; i < resp['state'].length; i++) {
          var eventUpdate = EventUpdate(
            type: 'state',
            roomID: id,
            eventType: resp['state'][i]['type'],
            content: resp['state'][i],
          ).decrypt(this);
          client.onEvent.add(eventUpdate);
        }
      }
    }

    List<dynamic> history = resp['chunk'];
    await client.store?.transaction(() {
      for (var i = 0; i < history.length; i++) {
        var eventUpdate = EventUpdate(
          type: 'history',
          roomID: id,
          eventType: history[i]['type'],
          content: history[i],
        ).decrypt(this);
        client.onEvent.add(eventUpdate);
        client.store.storeEventUpdate(eventUpdate);
        client.store.setRoomPrevBatch(id, resp['end']);
      }
      return;
    });
    if (client.store == null) {
      for (var i = 0; i < history.length; i++) {
        var eventUpdate = EventUpdate(
          type: 'history',
          roomID: id,
          eventType: history[i]['type'],
          content: history[i],
        ).decrypt(this);
        client.onEvent.add(eventUpdate);
      }
    }
    client.onRoomUpdate.add(
      RoomUpdate(
        id: id,
        membership: membership,
        prev_batch: resp['end'],
        notification_count: notificationCount,
        highlight_count: highlightCount,
      ),
    );
  }

  /// Sets this room as a direct chat for this user if not already.
  Future<void> addToDirectChat(String userID) async {
    var directChats = client.directChats;
    if (directChats.containsKey(userID)) {
      if (!directChats[userID].contains(id)) {
        directChats[userID].add(id);
      } else {
        return;
      } // Is already in direct chats
    } else {
      directChats[userID] = [id];
    }

    await client.jsonRequest(
        type: HTTPType.PUT,
        action: '/client/r0/user/${client.userID}/account_data/m.direct',
        data: directChats);
    return;
  }

  /// Removes this room from all direct chat tags.
  Future<void> removeFromDirectChat() async {
    var directChats = client.directChats;
    if (directChats.containsKey(directChatMatrixID) &&
        directChats[directChatMatrixID].contains(id)) {
      directChats[directChatMatrixID].remove(id);
    } else {
      return;
    } // Nothing to do here

    await client.jsonRequest(
        type: HTTPType.PUT,
        action: '/client/r0/user/${client.userID}/account_data/m.direct',
        data: directChats);
    return;
  }

  /// Sends *m.fully_read* and *m.read* for the given event ID.
  Future<void> sendReadReceipt(String eventID) async {
    notificationCount = 0;
    await client?.store?.resetNotificationCount(id);
    await client.jsonRequest(
        type: HTTPType.POST,
        action: '/client/r0/rooms/$id/read_markers',
        data: {
          'm.fully_read': eventID,
          'm.read': eventID,
        });
    return;
  }

  Future<void> restoreGroupSessionKeys() async {
    // Restore the inbound and outbound session keys
    if (client.encryptionEnabled && client.storeAPI != null) {
      final String outboundGroupSessionPickle = await client.storeAPI.getItem(
          '/clients/${client.deviceID}/rooms/${id}/outbound_group_session');
      if (outboundGroupSessionPickle != null) {
        try {
          _outboundGroupSession = olm.OutboundGroupSession();
          _outboundGroupSession.unpickle(
              client.userID, outboundGroupSessionPickle);
        } catch (e) {
          _outboundGroupSession = null;
          print('[LibOlm] Unable to unpickle outboundGroupSession: ' +
              e.toString());
        }
      }
      final String outboundGroupSessionDevicesString = await client.storeAPI
          .getItem(
              '/clients/${client.deviceID}/rooms/${id}/outbound_group_session_devices');
      if (outboundGroupSessionDevicesString != null) {
        _outboundGroupSessionDevices =
            List<String>.from(json.decode(outboundGroupSessionDevicesString));
      }
      final String sessionKeysPickle = await client.storeAPI
          .getItem('/clients/${client.deviceID}/rooms/${id}/session_keys');
      if (sessionKeysPickle?.isNotEmpty ?? false) {
        final Map<String, dynamic> map = json.decode(sessionKeysPickle);
        _sessionKeys ??= {};
        for (var entry in map.entries) {
          try {
            _sessionKeys[entry.key] =
                SessionKey.fromJson(entry.value, client.userID);
          } catch (e) {
            print('[LibOlm] Could not unpickle inboundGroupSession: ' +
                e.toString());
          }
        }
      }
    }
    await client.storeAPI?.setItem(
        '/clients/${client.deviceID}/rooms/${id}/session_keys',
        json.encode(sessionKeys));
    _tryAgainDecryptLastMessage();
    _fullyRestored = true;
    return;
  }

  bool _fullyRestored = false;

  /// Returns a Room from a json String which comes normally from the store. If the
  /// state are also given, the method will await them.
  static Future<Room> getRoomFromTableRow(
      Map<String, dynamic> row, Client matrix,
      {Future<List<Map<String, dynamic>>> states,
      Future<List<Map<String, dynamic>>> roomAccountData}) async {
    var newRoom = Room(
      id: row['room_id'],
      membership: Membership.values
          .firstWhere((e) => e.toString() == 'Membership.' + row['membership']),
      notificationCount: row['notification_count'],
      highlightCount: row['highlight_count'],
      notificationSettings: row['notification_settings'],
      prev_batch: row['prev_batch'],
      mInvitedMemberCount: row['invited_member_count'],
      mJoinedMemberCount: row['joined_member_count'],
      mHeroes: row['heroes']?.split(',') ?? [],
      client: matrix,
      roomAccountData: {},
    );

    // Restore the inbound and outbound session keys
    await newRoom.restoreGroupSessionKeys();

    if (states != null) {
      var rawStates = await states;
      for (var i = 0; i < rawStates.length; i++) {
        var newState = Event.fromJson(rawStates[i], newRoom);
        newRoom.setState(newState);
      }
    }

    var newRoomAccountData = <String, RoomAccountData>{};
    if (roomAccountData != null) {
      var rawRoomAccountData = await roomAccountData;
      for (var i = 0; i < rawRoomAccountData.length; i++) {
        var newData = RoomAccountData.fromJson(rawRoomAccountData[i], newRoom);
        newRoomAccountData[newData.typeKey] = newData;
      }
      newRoom.roomAccountData = newRoomAccountData;
    }

    return newRoom;
  }

  /// Creates a timeline from the store. Returns a [Timeline] object.
  Future<Timeline> getTimeline(
      {onTimelineUpdateCallback onUpdate,
      onTimelineInsertCallback onInsert}) async {
    var events = client.store != null
        ? await client.store.getEventList(this)
        : <Event>[];

    // Try again to decrypt encrypted events and update the database.
    if (encrypted && client.store != null) {
      await client.store.transaction(() {
        for (var i = 0; i < events.length; i++) {
          if (events[i].type == EventTypes.Encrypted &&
              events[i].content['body'] == DecryptError.UNKNOWN_SESSION) {
            events[i] = events[i].decrypted;
            if (events[i].type != EventTypes.Encrypted) {
              client.store.storeEventUpdate(
                EventUpdate(
                  eventType: events[i].typeKey,
                  content: events[i].toJson(),
                  roomID: events[i].roomId,
                  type: 'timeline',
                ),
              );
            }
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
    if (client.store == null) {
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
    if (states['m.room.member'] is Map<String, dynamic>) {
      for (var entry in states['m.room.member'].entries) {
        Event state = entry.value;
        if (state.type == EventTypes.RoomMember) userList.add(state.asUser);
      }
    }
    return userList;
  }

  /// Request the full list of participants from the server. The local list
  /// from the store is not complete if the client uses lazy loading.
  Future<List<User>> requestParticipants() async {
    if (participantListComplete) return getParticipants();
    var participants = <User>[];

    dynamic res = await client.jsonRequest(
        type: HTTPType.GET, action: '/client/r0/rooms/${id}/members');

    for (num i = 0; i < res['chunk'].length; i++) {
      var newUser = Event.fromJson(res['chunk'][i], this).asUser;
      if (![Membership.leave, Membership.ban].contains(newUser.membership)) {
        participants.add(newUser);
        setState(newUser);
      }
    }

    return participants;
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
  /// lazy loading.
  Future<User> requestUser(String mxID, {bool ignoreErrors = false}) async {
    if (mxID == null || !_requestingMatrixIds.add(mxID)) return null;
    Map<String, dynamic> resp;
    try {
      resp = await client.jsonRequest(
          type: HTTPType.GET,
          action: '/client/r0/rooms/$id/state/m.room.member/$mxID');
    } catch (exception) {
      _requestingMatrixIds.remove(mxID);
      if (!ignoreErrors) rethrow;
    }
    final user = User(mxID,
        displayName: resp['displayname'],
        avatarUrl: resp['avatar_url'],
        room: this);
    states[mxID] = user;
    if (client.store != null) {
      await client.store.transaction(() {
        client.store.storeEventUpdate(
          EventUpdate(
              content: resp,
              roomID: id,
              type: 'state',
              eventType: 'm.room.member'),
        );
        return;
      });
    }
    if (onUpdate != null) onUpdate.add(id);
    _requestingMatrixIds.remove(mxID);
    return user;
  }

  /// Searches for the event on the server. Returns null if not found.
  Future<Event> getEventById(String eventID) async {
    final dynamic resp = await client.jsonRequest(
        type: HTTPType.GET, action: '/client/r0/rooms/$id/event/$eventID');
    return Event.fromJson(resp, this);
  }

  /// Returns the power level of the given user ID.
  int getPowerLevelByUserId(String userId) {
    var powerLevel = 0;
    Event powerLevelState = states['m.room.power_levels'];
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
    Event powerLevelState = states['m.room.power_levels'];
    if (powerLevelState.content['users'] is Map<String, int>) {
      return powerLevelState.content['users'];
    }
    return null;
  }

  /// Uploads a new user avatar for this room. Returns the event ID of the new
  /// m.room.avatar event.
  Future<String> setAvatar(MatrixFile file) async {
    final uploadResp = await client.upload(file);
    final setAvatarResp = await client.jsonRequest(
        type: HTTPType.PUT,
        action: '/client/r0/rooms/$id/state/m.room.avatar/',
        data: {'url': uploadResp});
    return setAvatarResp['event_id'];
  }

  bool _hasPermissionFor(String action) {
    if (getState('m.room.power_levels') == null ||
        getState('m.room.power_levels').content[action] == null) return true;
    return ownPowerLevel >= getState('m.room.power_levels').content[action];
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

  bool get canChangePowerLevel => canSendEvent('m.room.power_levels');

  bool canSendEvent(String eventType) {
    if (getState('m.room.power_levels') == null) return true;
    if (getState('m.room.power_levels').content['events'] == null ||
        getState('m.room.power_levels').content['events'][eventType] == null) {
      return eventType == 'm.room.message'
          ? canSendDefaultMessages
          : canSendDefaultStates;
    }
    return ownPowerLevel >=
        getState('m.room.power_levels').content['events'][eventType];
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
  Future<dynamic> setPushRuleState(PushRuleState newState) async {
    if (newState == pushRuleState) return null;
    dynamic resp;
    switch (newState) {
      // All push notifications should be sent to the user
      case PushRuleState.notify:
        if (pushRuleState == PushRuleState.dont_notify) {
          resp = await client.jsonRequest(
              type: HTTPType.DELETE,
              action: '/client/r0/pushrules/global/override/$id',
              data: {});
        } else if (pushRuleState == PushRuleState.mentions_only) {
          resp = await client.jsonRequest(
              type: HTTPType.DELETE,
              action: '/client/r0/pushrules/global/room/$id',
              data: {});
        }
        break;
      // Only when someone mentions the user, a push notification should be sent
      case PushRuleState.mentions_only:
        if (pushRuleState == PushRuleState.dont_notify) {
          resp = await client.jsonRequest(
              type: HTTPType.DELETE,
              action: '/client/r0/pushrules/global/override/$id',
              data: {});
          resp = await client.jsonRequest(
              type: HTTPType.PUT,
              action: '/client/r0/pushrules/global/room/$id',
              data: {
                'actions': ['dont_notify']
              });
        } else if (pushRuleState == PushRuleState.notify) {
          resp = await client.jsonRequest(
              type: HTTPType.PUT,
              action: '/client/r0/pushrules/global/room/$id',
              data: {
                'actions': ['dont_notify']
              });
        }
        break;
      // No push notification should be ever sent for this room.
      case PushRuleState.dont_notify:
        if (pushRuleState == PushRuleState.mentions_only) {
          resp = await client.jsonRequest(
              type: HTTPType.DELETE,
              action: '/client/r0/pushrules/global/room/$id',
              data: {});
        }
        resp = await client.jsonRequest(
            type: HTTPType.PUT,
            action: '/client/r0/pushrules/global/override/$id',
            data: {
              'actions': ['dont_notify'],
              'conditions': [
                {'key': 'room_id', 'kind': 'event_match', 'pattern': id}
              ]
            });
    }
    return resp;
  }

  /// Redacts this event. Returns [ErrorResponse] on error.
  Future<dynamic> redactEvent(String eventId,
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
    final dynamic resp = await client.jsonRequest(
        type: HTTPType.PUT,
        action: '/client/r0/rooms/$id/redact/$eventId/$messageID',
        data: data);
    return resp;
  }

  Future<dynamic> sendTypingInfo(bool isTyping, {int timeout}) {
    var data = <String, dynamic>{
      'typing': isTyping,
    };
    if (timeout != null) data['timeout'] = timeout;
    return client.jsonRequest(
      type: HTTPType.PUT,
      action: '/client/r0/rooms/${id}/typing/${client.userID}',
      data: data,
    );
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
    final response = await client.jsonRequest(
      type: HTTPType.PUT,
      action: '/client/r0/rooms/$id/send/m.call.invite/$txid',
      data: {
        'call_id': callId,
        'lifetime': lifetime,
        'offer': {'sdp': sdp, 'type': type},
        'version': version,
      },
    );
    return response['event_id'];
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
    final response = await client.jsonRequest(
      type: HTTPType.PUT,
      action: '/client/r0/rooms/$id/send/m.call.candidates/$txid',
      data: {
        'call_id': callId,
        'candidates': candidates,
        'version': version,
      },
    );
    return response['event_id'];
  }

  /// This event is sent by the callee when they wish to answer the call.
  /// [callId] is a unique identifier for the call.
  /// [version] is the version of the VoIP specification this message adheres to. This specification is version 0.
  /// [type] The type of session description. Must be 'answer'.
  /// [sdp] The SDP text of the session description.
  Future<String> answerCall(String callId, String sdp,
      {String type = 'answer', int version = 0, String txid}) async {
    txid ??= 'txid${DateTime.now().millisecondsSinceEpoch}';
    final response = await client.jsonRequest(
      type: HTTPType.PUT,
      action: '/client/r0/rooms/$id/send/m.call.answer/$txid',
      data: {
        'call_id': callId,
        'answer': {'sdp': sdp, 'type': type},
        'version': version,
      },
    );
    return response['event_id'];
  }

  /// This event is sent by the callee when they wish to answer the call.
  /// [callId] The ID of the call this event relates to.
  /// [version] is the version of the VoIP specification this message adheres to. This specification is version 0.
  Future<String> hangupCall(String callId,
      {int version = 0, String txid}) async {
    txid ??= 'txid${DateTime.now().millisecondsSinceEpoch}';
    final response = await client.jsonRequest(
      type: HTTPType.PUT,
      action: '/client/r0/rooms/$id/send/m.call.hangup/$txid',
      data: {
        'call_id': callId,
        'version': version,
      },
    );
    return response['event_id'];
  }

  /// Returns all aliases for this room.
  List<String> get aliases {
    var aliases = <String>[];
    for (var aliasEvent in states.states['m.room.aliases'].values) {
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
  JoinRules get joinRules => getState('m.room.join_rules') != null
      ? JoinRules.values.firstWhere(
          (r) =>
              r.toString().replaceAll('JoinRules.', '') ==
              getState('m.room.join_rules').content['join_rule'],
          orElse: () => null)
      : null;

  /// Changes the join rules. You should check first if the user is able to change it.
  Future<void> setJoinRules(JoinRules joinRules) async {
    await client.jsonRequest(
      type: HTTPType.PUT,
      action: '/client/r0/rooms/$id/state/m.room.join_rules/',
      data: {
        'join_rule': joinRules.toString().replaceAll('JoinRules.', ''),
      },
    );
    return;
  }

  /// Whether the user has the permission to change the join rules.
  bool get canChangeJoinRules => canSendEvent('m.room.join_rules');

  /// This event controls whether guest users are allowed to join rooms. If this event
  /// is absent, servers should act as if it is present and has the guest_access value "forbidden".
  GuestAccess get guestAccess => getState('m.room.guest_access') != null
      ? GuestAccess.values.firstWhere(
          (r) =>
              r.toString().replaceAll('GuestAccess.', '') ==
              getState('m.room.guest_access').content['guest_access'],
          orElse: () => GuestAccess.forbidden)
      : GuestAccess.forbidden;

  /// Changes the guest access. You should check first if the user is able to change it.
  Future<void> setGuestAccess(GuestAccess guestAccess) async {
    await client.jsonRequest(
      type: HTTPType.PUT,
      action: '/client/r0/rooms/$id/state/m.room.guest_access/',
      data: {
        'guest_access': guestAccess.toString().replaceAll('GuestAccess.', ''),
      },
    );
    return;
  }

  /// Whether the user has the permission to change the guest access.
  bool get canChangeGuestAccess => canSendEvent('m.room.guest_access');

  /// This event controls whether a user can see the events that happened in a room from before they joined.
  HistoryVisibility get historyVisibility =>
      getState('m.room.history_visibility') != null
          ? HistoryVisibility.values.firstWhere(
              (r) =>
                  r.toString().replaceAll('HistoryVisibility.', '') ==
                  getState('m.room.history_visibility')
                      .content['history_visibility'],
              orElse: () => null)
          : null;

  /// Changes the history visibility. You should check first if the user is able to change it.
  Future<void> setHistoryVisibility(HistoryVisibility historyVisibility) async {
    await client.jsonRequest(
      type: HTTPType.PUT,
      action: '/client/r0/rooms/$id/state/m.room.history_visibility/',
      data: {
        'history_visibility':
            historyVisibility.toString().replaceAll('HistoryVisibility.', ''),
      },
    );
    return;
  }

  /// Whether the user has the permission to change the history visibility.
  bool get canChangeHistoryVisibility =>
      canSendEvent('m.room.history_visibility');

  /// Returns the encryption algorithm. Currently only `m.megolm.v1.aes-sha2` is supported.
  /// Returns null if there is no encryption algorithm.
  String get encryptionAlgorithm => getState('m.room.encryption') != null
      ? getState('m.room.encryption').content['algorithm'].toString()
      : null;

  /// Checks if this room is encrypted.
  bool get encrypted => encryptionAlgorithm != null;

  Future<void> enableEncryption({int algorithmIndex = 0}) async {
    if (encrypted) throw ('Encryption is already enabled!');
    final algorithm = Client.supportedGroupEncryptionAlgorithms[algorithmIndex];
    await client.jsonRequest(
      type: HTTPType.PUT,
      action: '/client/r0/rooms/$id/state/m.room.encryption/',
      data: {
        'algorithm': algorithm,
      },
    );
    return;
  }

  /// Returns all known device keys for all participants in this room.
  Future<List<DeviceKeys>> getUserDeviceKeys() async {
    var deviceKeys = <DeviceKeys>[];
    var users = await requestParticipants();
    for (final userDeviceKeyEntry in client.userDeviceKeys.entries) {
      if (users.indexWhere((u) => u.id == userDeviceKeyEntry.key) == -1) {
        continue;
      }
      for (var deviceKeyEntry in userDeviceKeyEntry.value.deviceKeys.values) {
        deviceKeys.add(deviceKeyEntry);
      }
    }
    return deviceKeys;
  }

  /// Encrypts the given json payload and creates a send-ready m.room.encrypted
  /// payload. This will create a new outgoingGroupSession if necessary.
  Future<Map<String, dynamic>> encryptGroupMessagePayload(
      Map<String, dynamic> payload,
      {String type = 'm.room.message'}) async {
    if (!encrypted || !client.encryptionEnabled) return payload;
    if (encryptionAlgorithm != 'm.megolm.v1.aes-sha2') {
      throw ('Unknown encryption algorithm');
    }
    if (_outboundGroupSession == null) {
      await createOutboundGroupSession();
    }
    final Map<String, dynamic> mRelatesTo = payload.remove('m.relates_to');
    final payloadContent = {
      'content': payload,
      'type': type,
      'room_id': id,
    };
    var encryptedPayload = <String, dynamic>{
      'algorithm': 'm.megolm.v1.aes-sha2',
      'ciphertext': _outboundGroupSession.encrypt(json.encode(payloadContent)),
      'device_id': client.deviceID,
      'sender_key': client.identityKey,
      'session_id': _outboundGroupSession.session_id(),
      if (mRelatesTo != null) 'm.relates_to': mRelatesTo,
    };
    await _storeOutboundGroupSession();
    return encryptedPayload;
  }

  /// Decrypts the given [event] with one of the available ingoingGroupSessions.
  /// Returns a m.bad.encrypted event if it fails and does nothing if the event
  /// was not encrypted.
  Event decryptGroupMessage(Event event) {
    if (event.type != EventTypes.Encrypted) return event;
    Map<String, dynamic> decryptedPayload;
    try {
      if (!client.encryptionEnabled) {
        throw (DecryptError.NOT_ENABLED);
      }
      if (event.content['algorithm'] != 'm.megolm.v1.aes-sha2') {
        throw (DecryptError.UNKNOWN_ALGORITHM);
      }
      final String sessionId = event.content['session_id'];
      if (!sessionKeys.containsKey(sessionId)) {
        throw (DecryptError.UNKNOWN_SESSION);
      }
      final decryptResult = sessionKeys[sessionId]
          .inboundGroupSession
          .decrypt(event.content['ciphertext']);
      final messageIndexKey =
          event.eventId + event.time.millisecondsSinceEpoch.toString();
      if (sessionKeys[sessionId].indexes.containsKey(messageIndexKey) &&
          sessionKeys[sessionId].indexes[messageIndexKey] !=
              decryptResult.message_index) {
        if ((_outboundGroupSession?.session_id() ?? '') == sessionId) {
          clearOutboundGroupSession();
        }
        throw (DecryptError.CHANNEL_CORRUPTED);
      }
      sessionKeys[sessionId].indexes[messageIndexKey] =
          decryptResult.message_index;
      _storeOutboundGroupSession();
      decryptedPayload = json.decode(decryptResult.plaintext);
    } catch (exception) {
      if (exception.toString() == DecryptError.UNKNOWN_SESSION) {
        decryptedPayload = {
          'content': event.content,
          'type': 'm.room.encrypted',
        };
        decryptedPayload['content']['body'] = exception.toString();
        decryptedPayload['content']['msgtype'] = 'm.bad.encrypted';
      } else {
        decryptedPayload = {
          'content': {
            'msgtype': 'm.bad.encrypted',
            'body': exception.toString(),
          },
          'type': 'm.room.encrypted',
        };
      }
    }
    if (event.content['m.relates_to'] != null) {
      decryptedPayload['content']['m.relates_to'] =
          event.content['m.relates_to'];
    }
    return Event(
      content: decryptedPayload['content'],
      typeKey: decryptedPayload['type'],
      senderId: event.senderId,
      eventId: event.eventId,
      roomId: event.roomId,
      room: event.room,
      time: event.time,
      unsigned: event.unsigned,
      stateKey: event.stateKey,
      prevContent: event.prevContent,
      status: event.status,
    );
  }
}

abstract class DecryptError {
  static const String NOT_ENABLED = 'Encryption is not enabled in your client.';
  static const String UNKNOWN_ALGORITHM = 'Unknown encryption algorithm.';
  static const String UNKNOWN_SESSION =
      'The sender has not sent us the session key.';
  static const String CHANNEL_CORRUPTED =
      'The secure channel with the sender was corrupted.';
}
