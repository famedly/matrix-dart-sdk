// @dart=2.9
/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020, 2021 Famedly GmbH
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
import 'dart:convert';

import 'package:html_unescape/html_unescape.dart';
import 'package:matrix/src/utils/space_child.dart';

import '../matrix.dart';
import 'client.dart';
import 'event.dart';
import 'timeline.dart';
import 'user.dart';
import 'utils/crypto/encrypted_file.dart';
import 'utils/event_update.dart';
import 'utils/markdown.dart';
import 'utils/marked_unread.dart';
import 'utils/matrix_file.dart';
import 'utils/matrix_localizations.dart';

enum PushRuleState { notify, mentionsOnly, dontNotify }
enum JoinRules { public, knock, invite, private }
enum GuestAccess { canJoin, forbidden }
enum HistoryVisibility { invited, joined, shared, worldReadable }

const Map<GuestAccess, String> _guestAccessMap = {
  GuestAccess.canJoin: 'can_join',
  GuestAccess.forbidden: 'forbidden',
};

const Map<HistoryVisibility, String> _historyVisibilityMap = {
  HistoryVisibility.invited: 'invited',
  HistoryVisibility.joined: 'joined',
  HistoryVisibility.shared: 'shared',
  HistoryVisibility.worldReadable: 'world_readable',
};

const String messageSendingStatusKey =
    'com.famedly.famedlysdk.message_sending_status';

const String sortOrderKey = 'com.famedly.famedlysdk.sort_order';

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

  RoomSummary summary;

  @deprecated
  List<String> get mHeroes => summary.mHeroes;

  @deprecated
  int get mJoinedMemberCount => summary.mJoinedMemberCount;

  @deprecated
  int get mInvitedMemberCount => summary.mInvitedMemberCount;

  /// The room states are a key value store of the key (`type`,`state_key`) => State(event).
  /// In a lot of cases the `state_key` might be an empty string. You **should** use the
  /// methods `getState()` and `setState()` to interact with the room states.
  Map<String, Map<String, Event>> states = {};

  /// Key-Value store for ephemerals.
  Map<String, BasicRoomEvent> ephemerals = {};

  /// Key-Value store for private account data only visible for this user.
  Map<String, BasicRoomEvent> roomAccountData = {};

  double _newestSortOrder;
  double _oldestSortOrder;

  Map<String, dynamic> toJson() => {
        'id': id,
        'membership': membership.toString().split('.').last,
        'highlight_count': highlightCount,
        'notification_count': notificationCount,
        'prev_batch': prev_batch,
        'summary': summary.toJson(),
        'newest_sort_order': 0,
        'oldest_sort_order': 0,
      };

  factory Room.fromJson(Map<String, dynamic> json, [Client client]) => Room(
        client: client,
        id: json['id'],
        membership: Membership.values.singleWhere(
          (m) => m.toString() == 'Membership.${json['membership']}',
          orElse: () => Membership.join,
        ),
        notificationCount: json['notification_count'],
        highlightCount: json['highlight_count'],
        prev_batch: json['prev_batch'],
        summary:
            RoomSummary.fromJson(Map<String, dynamic>.from(json['summary'])),
        newestSortOrder: json['newest_sort_order'].toDouble(),
        oldestSortOrder: json['oldest_sort_order'].toDouble(),
      );

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

  /// Post-loads the room.
  /// This load all the missing state events for the room from the database
  /// If the room has already been loaded, this does nothing.
  Future<void> postLoad() async {
    if (!partial || client.database == null) {
      return;
    }
    final allStates = await client.database
        .getUnimportantRoomEventStatesForRoom(
            client.id, client.importantStateEvents.toList(), this);

    for (final state in allStates) {
      setState(state);
    }
    partial = false;
  }

  /// Returns the [Event] for the given [typeKey] and optional [stateKey].
  /// If no [stateKey] is provided, it defaults to an empty string.
  Event getState(String typeKey, [String stateKey = '']) =>
      states[typeKey] != null ? states[typeKey][stateKey] : null;

  /// Adds the [state] to this room and overwrites a state with the same
  /// typeKey/stateKey key pair if there is one.
  void setState(Event state) {
    // Decrypt if necessary
    if (state.type == EventTypes.Encrypted && client.encryptionEnabled) {
      try {
        state = client.encryption.decryptRoomEventSync(id, state);
      } catch (e, s) {
        Logs().e('[LibOlm] Could not decrypt room state', e, s);
      }
    }
    if (!(state.stateKey is String) &&
            ![EventTypes.Message, EventTypes.Sticker, EventTypes.Encrypted]
                .contains(state.type) ||
        (state.type == EventTypes.Message &&
            state.messageType.startsWith('m.room.verification.'))) {
      return;
    }
    final oldStateEvent = getState(state.type, state.stateKey ?? '');
    if (oldStateEvent != null && oldStateEvent.sortOrder >= state.sortOrder) {
      return;
    }
    if (!states.containsKey(state.type)) {
      states[state.type] = {};
    }
    states[state.type][state.stateKey ?? ''] = state;
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
  String get name => getState(EventTypes.RoomName) != null &&
          getState(EventTypes.RoomName).content['name'] is String
      ? getState(EventTypes.RoomName).content['name']
      : '';

  /// The pinned events for this room. If there are none this returns an empty
  /// list.
  List<String> get pinnedEventIds => getState(EventTypes.RoomPinnedEvents) !=
          null
      ? (getState(EventTypes.RoomPinnedEvents).content['pinned'] is List<String>
          ? getState(EventTypes.RoomPinnedEvents).content['pinned']
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
        (summary.mHeroes != null && summary.mHeroes.isNotEmpty)) {
      return i18n.groupWith(displayname);
    }
    if (displayname?.isNotEmpty ?? false) {
      return displayname;
    }
    return i18n.emptyChat;
  }

  /// The topic of the room if set by a participant.
  String get topic => getState(EventTypes.RoomTopic) != null &&
          getState(EventTypes.RoomTopic).content['topic'] is String
      ? getState(EventTypes.RoomTopic).content['topic']
      : '';

  /// The avatar of the room if set by a participant.
  Uri get avatar {
    if (getState(EventTypes.RoomAvatar) != null &&
        getState(EventTypes.RoomAvatar).content['url'] is String) {
      return Uri.tryParse(getState(EventTypes.RoomAvatar).content['url']);
    }
    if (summary.mHeroes != null &&
        summary.mHeroes.length == 1 &&
        getState(EventTypes.RoomMember, summary.mHeroes.first) != null) {
      return getState(EventTypes.RoomMember, summary.mHeroes.first)
          .asUser
          .avatarUrl;
    }
    if (membership == Membership.invite &&
        getState(EventTypes.RoomMember, client.userID) != null) {
      return getState(EventTypes.RoomMember, client.userID).sender.avatarUrl;
    }
    return null;
  }

  /// The address in the format: #roomname:homeserver.org.
  String get canonicalAlias =>
      getState(EventTypes.RoomCanonicalAlias) != null &&
              getState(EventTypes.RoomCanonicalAlias).content['alias'] is String
          ? getState(EventTypes.RoomCanonicalAlias).content['alias']
          : '';

  /// Sets the canonical alias. If the [canonicalAlias] is not yet an alias of
  /// this room, it will create one.
  Future<void> setCanonicalAlias(String canonicalAlias) async {
    final aliases = await client.getLocalAliases(id);
    if (!aliases.contains(canonicalAlias)) {
      await client.setRoomAlias(canonicalAlias, id);
    }
    await client.setRoomStateWithKey(id, EventTypes.RoomCanonicalAlias, '', {
      'alias': canonicalAlias,
    });
  }

  /// If this room is a direct chat, this is the matrix ID of the user.
  /// Returns null otherwise.
  String get directChatMatrixID {
    String returnUserId;
    if (membership == Membership.invite) {
      final invitation = getState(EventTypes.RoomMember, client.userID);
      if (invitation != null && invitation.content['is_direct'] == true) {
        return invitation.senderId;
      }
    }
    if (client.directChats is Map<String, dynamic>) {
      client.directChats.forEach((String userId, dynamic roomIds) {
        if (roomIds is List<dynamic> && roomIds.contains(id)) {
          returnUserId = userId;
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
    final lastEvents =
        client.roomPreviewLastEvents.map(getState).where((e) => e != null);

    var lastEvent = lastEvents.isEmpty
        ? null
        : lastEvents.reduce((a, b) {
            if (a.sortOrder == b.sortOrder) {
              // if two events have the same sort order we want to give encrypted events a lower priority
              // This is so that if the same event exists in the state both encrypted *and* unencrypted,
              // the unencrypted one is picked
              return a.type == EventTypes.Encrypted ? b : a;
            }
            return a.sortOrder > b.sortOrder ? a : b;
          });
    if (lastEvent == null) {
      states.forEach((final String key, final entry) {
        if (!entry.containsKey('')) return;
        final state = entry[''];
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
    final List<dynamic> typingMxid = ephemerals['m.typing'].content['user_ids'];
    return typingMxid.cast<String>().map(getUserByMXIDSync).toList();
  }

  /// Your current client instance.
  final Client client;

  Room({
    this.id,
    this.membership = Membership.join,
    int notificationCount,
    int highlightCount,
    String prev_batch,
    this.client,
    this.notificationSettings,
    Map<String, BasicRoomEvent> roomAccountData,
    double newestSortOrder = 0.0,
    double oldestSortOrder = 0.0,
    RoomSummary summary,
  })  : _newestSortOrder = newestSortOrder,
        _oldestSortOrder = oldestSortOrder,
        notificationCount = notificationCount ?? 0,
        highlightCount = highlightCount ?? 0,
        prev_batch = prev_batch ?? '',
        roomAccountData = roomAccountData ?? <String, BasicRoomEvent>{},
        summary = summary ??
            RoomSummary.fromJson({
              'm.joined_member_count': 0,
              'm.invited_member_count': 0,
              'm.heroes': [],
            });

  /// The default count of how much events should be requested when requesting the
  /// history of this room.
  static const int defaultHistoryCount = 100;

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
    if (summary.mHeroes != null &&
        summary.mHeroes.isNotEmpty &&
        summary.mHeroes.any((h) => h.isNotEmpty)) {
      heroes = summary.mHeroes;
    } else {
      if (states[EventTypes.RoomMember] is Map<String, dynamic>) {
        for (final entry in states[EventTypes.RoomMember].entries) {
          final state = entry.value;
          if (state.type == EventTypes.RoomMember &&
              state.stateKey != client?.userID) heroes.add(state.stateKey);
        }
      }
    }
    if (heroes.isNotEmpty) {
      return heroes
          .where((hero) => hero.isNotEmpty)
          .map((hero) => getUserByMXIDSync(hero).calcDisplayname())
          .join(', ');
    }
    if (membership == Membership.invite &&
        getState(EventTypes.RoomMember, client.userID) != null) {
      return getState(EventTypes.RoomMember, client.userID)
          .sender
          .calcDisplayname();
    }
    return 'Empty chat';
  }

  @Deprecated('Use [lastEvent.body] instead')
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
  Future<String> setName(String newName) => client.setRoomStateWithKey(
        id,
        EventTypes.RoomName,
        '',
        {'name': newName},
      );

  /// Call the Matrix API to change the topic of this room.
  Future<String> setDescription(String newName) => client.setRoomStateWithKey(
        id,
        EventTypes.RoomTopic,
        '',
        {'topic': newName},
      );

  /// Add a tag to the room.
  Future<void> addTag(String tag, {double order}) => client.setRoomTag(
        client.userID,
        id,
        tag,
        order: order,
      );

  /// Removes a tag from the room.
  Future<void> removeTag(String tag) => client.deleteRoomTag(
        client.userID,
        id,
        tag,
      );

  // Tag is part of client-to-server-API, so it uses strict parsing.
  // For roomAccountData, permissive parsing is more suitable,
  // so it is implemented here.
  static Tag _tryTagFromJson(Object o) {
    if (o is Map<String, dynamic>) {
      return Tag(
          order: o.tryGet<num>('order')?.toDouble(),
          additionalProperties: Map.from(o)..remove('order'));
    }
    return Tag();
  }

  /// Returns all tags for this room.
  Map<String, Tag> get tags {
    if (roomAccountData['m.tag'] == null ||
        !(roomAccountData['m.tag'].content['tags'] is Map)) {
      return {};
    }
    final tags = (roomAccountData['m.tag'].content['tags'] as Map)
        .map((k, v) => MapEntry<String, Tag>(k, _tryTagFromJson(v)));
    tags.removeWhere((k, v) => !TagType.isValid(k));
    return tags;
  }

  bool get markedUnread {
    return MarkedUnread.fromJson(
            roomAccountData[EventType.markedUnread]?.content ?? {})
        .unread;
  }

  /// Returns true if this room is unread
  bool get isUnread => notificationCount > 0 || markedUnread;

  /// Sets an unread flag manually for this room. Similar to the setUnreadMarker
  /// this changes the local account data model before syncing it to make sure
  /// this works if there is no connection to the homeserver.
  Future<void> setUnread(bool unread) async {
    final content = MarkedUnread(unread).toJson();
    await _handleFakeSync(SyncUpdate(nextBatch: '')
      ..rooms = (RoomsUpdate()
        ..join = (({}..[id] = (JoinedRoomUpdate()
          ..accountData = [
            BasicRoomEvent(
              content: content,
              roomId: id,
              type: EventType.markedUnread,
            )
          ])))));
    await client.setAccountDataPerRoom(
      client.userID,
      id,
      EventType.markedUnread,
      content,
    );
    if (unread == false && lastEvent != null) {
      await setReadMarker(
        lastEvent.eventId,
        mRead: lastEvent.eventId,
      );
    }
  }

  /// Returns true if this room has a m.favourite tag.
  bool get isFavourite => tags[TagType.favourite] != null;

  /// Sets the m.favourite tag for this room.
  Future<void> setFavourite(bool favourite) =>
      favourite ? addTag(TagType.favourite) : removeTag(TagType.favourite);

  /// Call the Matrix API to change the pinned events of this room.
  Future<String> setPinnedEvents(List<String> pinnedEventIds) =>
      client.setRoomStateWithKey(
        id,
        EventTypes.RoomPinnedEvents,
        '',
        {'pinned': pinnedEventIds},
      );

  /// return all current emote packs for this room
  @deprecated
  Map<String, Map<String, String>> get emotePacks =>
      getImagePacksFlat(ImagePackUsage.emoticon);

  /// Sends a normal text message to this room. Returns the event ID generated
  /// by the server for this message.
  Future<String> sendTextEvent(String message,
      {String txid,
      Event inReplyTo,
      String editEventId,
      bool parseMarkdown = true,
      @deprecated Map<String, Map<String, String>> emotePacks,
      bool parseCommands = true,
      String msgtype = MessageTypes.Text}) {
    if (parseCommands) {
      return client.parseAndRunCommand(this, message,
          inReplyTo: inReplyTo, editEventId: editEventId, txid: txid);
    }
    final event = <String, dynamic>{
      'msgtype': msgtype,
      'body': message,
    };
    if (parseMarkdown) {
      final mentionMap = <String, String>{
        for (final user in getParticipants()) user.mention: user.id
      };
      final html = markdown(event['body'],
          emotePacks: getImagePacksFlat(ImagePackUsage.emoticon),
          mentionMap: mentionMap);
      // if the decoded html is the same as the body, there is no need in sending a formatted message
      if (HtmlUnescape().convert(html.replaceAll(RegExp(r'<br />\n?'), '\n')) !=
          event['body']) {
        event['format'] = 'org.matrix.custom.html';
        event['formatted_body'] = html;
      }
    }
    return sendEvent(event,
        txid: txid, inReplyTo: inReplyTo, editEventId: editEventId);
  }

  /// Sends a reaction to an event with an [eventId] and the content [key] into a room.
  /// Returns the event ID generated by the server for this reaction.
  Future<String> sendReaction(String eventId, String key, {String txid}) {
    return sendEvent({
      'm.relates_to': {
        'rel_type': RelationshipTypes.reaction,
        'event_id': eventId,
        'key': key,
      },
    }, type: EventTypes.Reaction, txid: txid);
  }

  /// Sends the location with description [body] and geo URI [geoUri] into a room.
  /// Returns the event ID generated by the server for this message.
  Future<String> sendLocation(String body, String geoUri, {String txid}) {
    final event = <String, dynamic>{
      'msgtype': 'm.location',
      'body': body,
      'geo_uri': geoUri,
    };
    return sendEvent(event, txid: txid);
  }

  /// Sends a [file] to this room after uploading it. Returns the mxc uri of
  /// the uploaded file. If [waitUntilSent] is true, the future will wait until
  /// the message event has received the server. Otherwise the future will only
  /// wait until the file has been uploaded.
  /// Optionally specify [extraContent] to tack on to the event.
  Future<Uri> sendFileEvent(
    MatrixFile file, {
    String txid,
    Event inReplyTo,
    String editEventId,
    bool waitUntilSent = false,
    MatrixImageFile thumbnail,
    Map<String, dynamic> extraContent,
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
    final uploadResp = await client.uploadContent(
      uploadFile.bytes,
      filename: uploadFile.name,
      contentType: uploadFile.mimeType,
    );
    final thumbnailUploadResp = uploadThumbnail != null
        ? await client.uploadContent(
            uploadThumbnail.bytes,
            filename: uploadThumbnail.name,
            contentType: uploadThumbnail.mimeType,
          )
        : null;

    // Send event
    final content = <String, dynamic>{
      'msgtype': file.msgType,
      'body': file.name,
      'filename': file.name,
      if (encryptedFile == null) 'url': uploadResp.toString(),
      if (encryptedFile != null)
        'file': {
          'url': uploadResp.toString(),
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
            'url': thumbnailUploadResp.toString(),
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
      },
      if (extraContent != null) ...extraContent,
    };
    final sendResponse = sendEvent(
      content,
      txid: txid,
      inReplyTo: inReplyTo,
      editEventId: editEventId,
    );
    if (waitUntilSent) {
      await sendResponse;
    }
    return uploadResp;
  }

  Future<String> _sendContent(
    String type,
    Map<String, dynamic> content, {
    String txid,
  }) async {
    txid ??= client.generateUniqueTransactionId();
    final mustEncrypt = encrypted && client.encryptionEnabled;
    final sendMessageContent = mustEncrypt
        ? await client.encryption
            .encryptGroupMessagePayload(id, content, type: type)
        : content;
    return await client.sendMessage(
      id,
      mustEncrypt ? EventTypes.Encrypted : type,
      txid,
      sendMessageContent,
    );
  }

  /// Sends an event to this room with this json as a content. Returns the
  /// event ID generated from the server.
  Future<String> sendEvent(
    Map<String, dynamic> content, {
    String type,
    String txid,
    Event inReplyTo,
    String editEventId,
  }) async {
    type = type ?? EventTypes.Message;

    // Create new transaction id
    String messageID;
    if (txid == null) {
      messageID = client.generateUniqueTransactionId();
    } else {
      messageID = txid;
    }

    if (inReplyTo != null) {
      var replyText = '<${inReplyTo.senderId}> ' + inReplyTo.body;
      replyText = replyText.split('\n').map((line) => '> $line').join('\n');
      content['format'] = 'org.matrix.custom.html';
      // be sure that we strip any previous reply fallbacks
      final replyHtml = (inReplyTo.formattedText.isNotEmpty
              ? inReplyTo.formattedText
              : htmlEscape.convert(inReplyTo.body).replaceAll('\n', '<br>'))
          .replaceAll(
              RegExp(r'<mx-reply>.*<\/mx-reply>',
                  caseSensitive: false, multiLine: false, dotAll: true),
              '');
      final repliedHtml = content.tryGet<String>('formatted_body') ??
          htmlEscape
              .convert(content.tryGet<String>('body') ?? '')
              .replaceAll('\n', '<br>');
      content['formatted_body'] =
          '<mx-reply><blockquote><a href="https://matrix.to/#/${inReplyTo.room.id}/${inReplyTo.eventId}">In reply to</a> <a href="https://matrix.to/#/${inReplyTo.senderId}">${inReplyTo.senderId}</a><br>$replyHtml</blockquote></mx-reply>$repliedHtml';
      // We escape all @room-mentions here to prevent accidental room pings when an admin
      // replies to a message containing that!
      content['body'] =
          '${replyText.replaceAll('@room', '@\u200broom')}\n\n${content.tryGet<String>('body') ?? ''}';
      content['m.relates_to'] = {
        'm.in_reply_to': {
          'event_id': inReplyTo.eventId,
        },
      };
    }
    if (editEventId != null) {
      final newContent = content.copy();
      content['m.new_content'] = newContent;
      content['m.relates_to'] = {
        'event_id': editEventId,
        'rel_type': RelationshipTypes.edit,
      };
      if (content['body'] is String) {
        content['body'] = '* ' + content['body'];
      }
      if (content['formatted_body'] is String) {
        content['formatted_body'] = '* ' + content['formatted_body'];
      }
    }
    final sentDate = DateTime.now();
    final syncUpdate = SyncUpdate(nextBatch: '')
      ..rooms = (RoomsUpdate()
        ..join = (<String, JoinedRoomUpdate>{}..[id] = (JoinedRoomUpdate()
          ..timeline = (TimelineUpdate()
            ..events = [
              MatrixEvent(
                content: content,
                type: type,
                eventId: messageID,
                senderId: client.userID,
                originServerTs: sentDate,
                unsigned: {
                  messageSendingStatusKey: 0,
                  'transaction_id': messageID,
                },
              )
            ]))));
    await _handleFakeSync(syncUpdate);

    // Send the text and on success, store and display a *sent* event.
    String res;
    while (res == null) {
      try {
        res = await _sendContent(
          type,
          content,
          txid: messageID,
        );
      } catch (e, s) {
        if ((DateTime.now().millisecondsSinceEpoch -
                sentDate.millisecondsSinceEpoch) <
            (1000 * client.sendMessageTimeoutSeconds)) {
          Logs().w('[Client] Problem while sending message because of "' +
              e.toString() +
              '". Try again in 1 seconds...');
          await Future.delayed(Duration(seconds: 1));
        } else {
          Logs().w('[Client] Problem while sending message', e, s);
          syncUpdate.rooms.join.values.first.timeline.events.first
              .unsigned[messageSendingStatusKey] = -1;
          await _handleFakeSync(syncUpdate);
          return null;
        }
      }
    }
    syncUpdate.rooms.join.values.first.timeline.events.first
        .unsigned[messageSendingStatusKey] = 1;
    syncUpdate.rooms.join.values.first.timeline.events.first.eventId = res;
    await _handleFakeSync(syncUpdate);

    return res;
  }

  /// Call the Matrix API to join this room if the user is not already a member.
  /// If this room is intended to be a direct chat, the direct chat flag will
  /// automatically be set.
  Future<void> join({bool leaveIfNotFound = true}) async {
    try {
      await client.joinRoomById(id);
      final invitation = getState(EventTypes.RoomMember, client.userID);
      if (invitation != null &&
          invitation.content['is_direct'] is bool &&
          invitation.content['is_direct']) {
        await addToDirectChat(invitation.sender.id);
      }
    } on MatrixException catch (exception) {
      if (leaveIfNotFound &&
          [MatrixError.M_NOT_FOUND, MatrixError.M_UNKNOWN]
              .contains(exception.error)) {
        await leave();
      }
      rethrow;
    }
    return;
  }

  /// Call the Matrix API to leave this room. If this room is set as a direct
  /// chat, this will be removed too.
  Future<void> leave() async {
    if (directChatMatrixID != '') await removeFromDirectChat();
    try {
      await client.leaveRoom(id);
    } on MatrixException catch (exception) {
      if ([MatrixError.M_NOT_FOUND, MatrixError.M_UNKNOWN]
          .contains(exception.error)) {
        await _handleFakeSync(
          SyncUpdate(nextBatch: '')
            ..rooms = (RoomsUpdate()
              ..leave = {
                '$id': (LeftRoomUpdate()),
              }),
        );
      }
      rethrow;
    }
    return;
  }

  /// Call the Matrix API to forget this room if you already left it.
  Future<void> forget() async {
    await client.database?.forgetRoom(client.id, id);
    await client.forgetRoom(id);
    return;
  }

  /// Call the Matrix API to kick a user from this room.
  Future<void> kick(String userID) => client.kick(id, userID);

  /// Call the Matrix API to ban a user from this room.
  Future<void> ban(String userID) => client.ban(id, userID);

  /// Call the Matrix API to unban a banned user from this room.
  Future<void> unban(String userID) => client.unban(id, userID);

  /// Set the power level of the user with the [userID] to the value [power].
  /// Returns the event ID of the new state event. If there is no known
  /// power level event, there might something broken and this returns null.
  Future<String> setPower(String userID, int power) async {
    if (getState(EventTypes.RoomPowerLevels) == null) return null;
    final powerMap = <String, dynamic>{}
      ..addAll(getState(EventTypes.RoomPowerLevels).content);
    if (powerMap['users'] == null) powerMap['users'] = {};
    powerMap['users'][userID] = power;

    return await client.setRoomStateWithKey(
      id,
      EventTypes.RoomPowerLevels,
      '',
      powerMap,
    );
  }

  /// Call the Matrix API to invite a user to this room.
  Future<void> invite(String userID) => client.inviteUser(id, userID);

  /// Request more previous events from the server. [historyCount] defines how much events should
  /// be received maximum. When the request is answered, [onHistoryReceived] will be triggered **before**
  /// the historical events will be published in the onEvent stream.
  Future<void> requestHistory(
      {int historyCount = defaultHistoryCount, onHistoryReceived}) async {
    final resp = await client.getRoomEvents(
      id,
      prev_batch,
      Direction.b,
      limit: historyCount,
      filter: jsonEncode(StateFilter(lazyLoadMembers: true).toJson()),
    );

    if (onHistoryReceived != null) onHistoryReceived();
    prev_batch = resp.end;

    final loadFn = () async {
      if (!((resp.chunk?.isNotEmpty ?? false) && resp.end != null)) return;

      await client.handleSync(
          SyncUpdate(nextBatch: '')
            ..rooms = (RoomsUpdate()
              ..join = ({}..[id] = (JoinedRoomUpdate()
                ..state = resp.state
                ..timeline = (TimelineUpdate()
                  ..limited = false
                  ..events = resp.chunk
                  ..prevBatch = resp.end)))),
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
    final directChats = client.directChats;
    if (directChats[userID] is List) {
      if (!directChats[userID].contains(id)) {
        directChats[userID].add(id);
      } else {
        return;
      } // Is already in direct chats
    } else {
      directChats[userID] = [id];
    }

    await client.setAccountData(
      client.userID,
      'm.direct',
      directChats,
    );
    return;
  }

  /// Removes this room from all direct chat tags.
  Future<void> removeFromDirectChat() async {
    final directChats = client.directChats;
    if (directChats[directChatMatrixID] is List &&
        directChats[directChatMatrixID].contains(id)) {
      directChats[directChatMatrixID].remove(id);
    } else {
      return;
    } // Nothing to do here

    await client.setAccountDataPerRoom(
      client.userID,
      id,
      'm.direct',
      directChats,
    );
    return;
  }

  /// Sets the position of the read marker for a given room, and optionally the
  /// read receipt's location.
  Future<void> setReadMarker(String eventId, {String mRead}) async {
    if (mRead != null) {
      notificationCount = 0;
      await client.database?.resetNotificationCount(client.id, id);
    }
    await client.setReadMarker(
      id,
      eventId,
      mRead: mRead,
    );
    return;
  }

  /// This API updates the marker for the given receipt type to the event ID
  /// specified.
  Future<void> postReceipt(String eventId) async {
    notificationCount = 0;
    await client.database?.resetNotificationCount(client.id, id);
    await client.postReceipt(
      id,
      ReceiptType.mRead,
      eventId,
      {},
    );
    return;
  }

  /// Sends *m.fully_read* and *m.read* for the given event ID.
  @Deprecated('Use sendReadMarker instead')
  Future<void> sendReadReceipt(String eventID) async {
    notificationCount = 0;
    await client.database?.resetNotificationCount(client.id, id);
    await client.setReadMarker(
      id,
      eventID,
      mRead: eventID,
    );
    return;
  }

  /// Creates a timeline from the store. Returns a [Timeline] object.
  Future<Timeline> getTimeline(
      {void Function() onUpdate, void Function(int insertID) onInsert}) async {
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

    final timeline = Timeline(
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
    final userList = <User>[];
    if (states[EventTypes.RoomMember] is Map<String, dynamic>) {
      for (final entry in states[EventTypes.RoomMember].entries) {
        final state = entry.value;
        if (state.type == EventTypes.RoomMember) userList.add(state.asUser);
      }
    }
    return userList;
  }

  bool _requestedParticipants = false;

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
    if (_requestedParticipants || participantListComplete) {
      return getParticipants();
    }
    final matrixEvents = await client.getMembersByRoom(id);
    final users =
        matrixEvents.map((e) => Event.fromMatrixEvent(e, this).asUser).toList();
    for (final user in users) {
      setState(user); // at *least* cache this in-memory
    }
    _requestedParticipants = true;
    users.removeWhere(
        (u) => [Membership.leave, Membership.ban].contains(u.membership));
    return users;
  }

  /// Checks if the local participant list of joined and invited users is complete.
  bool get participantListComplete {
    final knownParticipants = getParticipants();
    knownParticipants.removeWhere(
        (u) => ![Membership.join, Membership.invite].contains(u.membership));
    return knownParticipants.length ==
        (summary.mJoinedMemberCount ?? 0) + (summary.mInvitedMemberCount ?? 0);
  }

  /// Returns the [User] object for the given [mxID] or requests it from
  /// the homeserver and waits for a response.
  @Deprecated('Use [requestUser] instead')
  Future<User> getUserByMXID(String mxID) async {
    if (getState(EventTypes.RoomMember, mxID) != null) {
      return getState(EventTypes.RoomMember, mxID).asUser;
    }
    return requestUser(mxID);
  }

  /// Returns the [User] object for the given [mxID] or requests it from
  /// the homeserver and returns a default [User] object while waiting.
  User getUserByMXIDSync(String mxID) {
    if (getState(EventTypes.RoomMember, mxID) != null) {
      return getState(EventTypes.RoomMember, mxID).asUser;
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
    // TODO: Why is this bug happening at all?
    if (mxID == null) {
      // Show a warning but first generate a stacktrace.
      try {
        throw Exception();
      } catch (e, s) {
        Logs().w('requestUser has been called with a null mxID', e, s);
      }
      return null;
    }

    if (getState(EventTypes.RoomMember, mxID) != null) {
      return getState(EventTypes.RoomMember, mxID).asUser;
    }
    if (client.database != null) {
      // it may be in the database
      final user = await client.database.getUser(client.id, mxID, this);
      if (user != null) {
        setState(user);
        onUpdate.add(id);
        return user;
      }
    }
    if (!_requestingMatrixIds.add(mxID)) return null;
    Map<String, dynamic> resp;
    try {
      Logs().v(
          'Request missing user $mxID in room $displayname from the server...');
      resp = await client.requestStateContent(
        id,
        EventTypes.RoomMember,
        mxID,
      );
    } catch (e, s) {
      if (!ignoreErrors) {
        _requestingMatrixIds.remove(mxID);
        rethrow;
      } else {
        Logs().w('Unable to request the user $mxID from the server', e, s);
      }
    }
    if (resp == null && requestProfile) {
      try {
        final profile = await client.getUserProfile(mxID);
        resp = {
          'displayname': profile.displayname,
          'avatar_url': profile.avatarUrl.toString(),
        };
      } catch (e, s) {
        _requestingMatrixIds.remove(mxID);
        if (!ignoreErrors) {
          rethrow;
        } else {
          Logs().w('Unable to request the profile $mxID from the server', e, s);
        }
      }
    }
    if (resp == null) {
      return null;
    }
    final user = User(mxID,
        displayName: resp['displayname'],
        avatarUrl: resp['avatar_url'],
        room: this);
    setState(user);
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
            type: EventUpdateType.state,
            sortOrder: 0.0),
      );
    });
    onUpdate.add(id);
    _requestingMatrixIds.remove(mxID);
    return user;
  }

  /// Searches for the event on the server. Returns null if not found.
  Future<Event> getEventById(String eventID) async {
    try {
      final matrixEvent = await client.getOneRoomEvent(id, eventID);
      final event = Event.fromMatrixEvent(matrixEvent, this);
      if (event.type == EventTypes.Encrypted && client.encryptionEnabled) {
        // attempt decryption
        return await client.encryption
            .decryptRoomEvent(id, event, store: false);
      }
      return event;
    } on MatrixException catch (err) {
      if (err.errcode == 'M_NOT_FOUND') {
        return null;
      }
      rethrow;
    }
  }

  /// Returns the power level of the given user ID.
  int getPowerLevelByUserId(String userId) {
    var powerLevel = 0;
    final powerLevelState = getState(EventTypes.RoomPowerLevels);
    if (powerLevelState == null) return powerLevel;
    if (powerLevelState.content['users_default'] is int) {
      powerLevel = powerLevelState.content['users_default'];
    }
    if (powerLevelState.content
            .tryGet<Map<String, dynamic>>('users')
            ?.tryGet<int>(userId) !=
        null) {
      powerLevel = powerLevelState.content['users'][userId];
    }
    return powerLevel;
  }

  /// Returns the user's own power level.
  int get ownPowerLevel => getPowerLevelByUserId(client.userID);

  /// Returns the power levels from all users for this room or null if not given.
  Map<String, int> get powerLevels {
    final powerLevelState = getState(EventTypes.RoomPowerLevels);
    if (powerLevelState.content['users'] is Map<String, int>) {
      return powerLevelState.content['users'];
    }
    return null;
  }

  /// Uploads a new user avatar for this room. Returns the event ID of the new
  /// m.room.avatar event.
  Future<String> setAvatar(MatrixFile file) async {
    final uploadResp =
        await client.uploadContent(file.bytes, filename: file.name);
    return await client.setRoomStateWithKey(
      id,
      EventTypes.RoomAvatar,
      '',
      {'url': uploadResp.toString()},
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
      for (final pushRule in globalPushRules['override']) {
        if (pushRule['rule_id'] == id) {
          if (pushRule['actions'].indexOf('dont_notify') != -1) {
            return PushRuleState.dontNotify;
          }
          break;
        }
      }
    }

    if (globalPushRules['room'] is List) {
      for (final pushRule in globalPushRules['room']) {
        if (pushRule['rule_id'] == id) {
          if (pushRule['actions'].indexOf('dont_notify') != -1) {
            return PushRuleState.mentionsOnly;
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
        if (pushRuleState == PushRuleState.dontNotify) {
          await client.deletePushRule('global', PushRuleKind.override, id);
        } else if (pushRuleState == PushRuleState.mentionsOnly) {
          await client.deletePushRule('global', PushRuleKind.room, id);
        }
        break;
      // Only when someone mentions the user, a push notification should be sent
      case PushRuleState.mentionsOnly:
        if (pushRuleState == PushRuleState.dontNotify) {
          await client.deletePushRule('global', PushRuleKind.override, id);
          await client.setPushRule(
            'global',
            PushRuleKind.room,
            id,
            [PushRuleAction.dontNotify],
          );
        } else if (pushRuleState == PushRuleState.notify) {
          await client.setPushRule(
            'global',
            PushRuleKind.room,
            id,
            [PushRuleAction.dontNotify],
          );
        }
        break;
      // No push notification should be ever sent for this room.
      case PushRuleState.dontNotify:
        if (pushRuleState == PushRuleState.mentionsOnly) {
          await client.deletePushRule('global', PushRuleKind.room, id);
        }
        await client.setPushRule(
          'global',
          PushRuleKind.override,
          id,
          [PushRuleAction.dontNotify],
          conditions: [
            PushCondition(kind: 'event_match', key: 'room_id', pattern: id)
          ],
        );
    }
    return resp;
  }

  /// Redacts this event. Throws `ErrorResponse` on error.
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
    final data = <String, dynamic>{};
    if (reason != null) data['reason'] = reason;
    return await client.redactEvent(
      id,
      eventId,
      messageID,
      reason: reason,
    );
  }

  /// This tells the server that the user is typing for the next N milliseconds
  /// where N is the value specified in the timeout key. Alternatively, if typing is false,
  /// it tells the server that the user has stopped typing.
  Future<void> setTyping(bool isTyping, {int timeout}) =>
      client.setTyping(client.userID, id, isTyping, timeout: timeout);

  @Deprecated('Use sendTypingNotification instead')
  Future<void> sendTypingInfo(bool isTyping, {int timeout}) =>
      setTyping(isTyping, timeout: timeout);

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

    final content = {
      'call_id': callId,
      'lifetime': lifetime,
      'offer': {'sdp': sdp, 'type': type},
      'version': version,
    };
    return await _sendContent(
      EventTypes.CallInvite,
      content,
      txid: txid,
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
    final content = {
      'call_id': callId,
      'candidates': candidates,
      'version': version,
    };
    return await _sendContent(
      EventTypes.CallCandidates,
      content,
      txid: txid,
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
    final content = {
      'call_id': callId,
      'answer': {'sdp': sdp, 'type': type},
      'version': version,
    };
    return await _sendContent(
      EventTypes.CallAnswer,
      content,
      txid: txid,
    );
  }

  /// This event is sent by the callee when they wish to answer the call.
  /// [callId] The ID of the call this event relates to.
  /// [version] is the version of the VoIP specification this message adheres to. This specification is version 0.
  Future<String> hangupCall(String callId,
      {int version = 0, String txid}) async {
    txid ??= 'txid${DateTime.now().millisecondsSinceEpoch}';

    final content = {
      'call_id': callId,
      'version': version,
    };
    return await _sendContent(
      EventTypes.CallHangup,
      content,
      txid: txid,
    );
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
    await client.setRoomStateWithKey(
      id,
      EventTypes.RoomJoinRules,
      '',
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
      ? _guestAccessMap.map((k, v) => MapEntry(v, k))[
          getState(EventTypes.GuestAccess).content['guest_access']]
      : GuestAccess.forbidden;

  /// Changes the guest access. You should check first if the user is able to change it.
  Future<void> setGuestAccess(GuestAccess guestAccess) async {
    await client.setRoomStateWithKey(
      id,
      EventTypes.GuestAccess,
      '',
      {
        'guest_access': _guestAccessMap[guestAccess],
      },
    );
    return;
  }

  /// Whether the user has the permission to change the guest access.
  bool get canChangeGuestAccess => canSendEvent(EventTypes.GuestAccess);

  /// This event controls whether a user can see the events that happened in a room from before they joined.
  HistoryVisibility get historyVisibility =>
      getState(EventTypes.HistoryVisibility) != null
          ? _historyVisibilityMap.map((k, v) => MapEntry(v, k))[
              getState(EventTypes.HistoryVisibility)
                  .content['history_visibility']]
          : null;

  /// Changes the history visibility. You should check first if the user is able to change it.
  Future<void> setHistoryVisibility(HistoryVisibility historyVisibility) async {
    await client.setRoomStateWithKey(
      id,
      EventTypes.HistoryVisibility,
      '',
      {
        'history_visibility': _historyVisibilityMap[historyVisibility],
      },
    );
    return;
  }

  /// Whether the user has the permission to change the history visibility.
  bool get canChangeHistoryVisibility =>
      canSendEvent(EventTypes.HistoryVisibility);

  /// Returns the encryption algorithm. Currently only `m.megolm.v1.aes-sha2` is supported.
  /// Returns null if there is no encryption algorithm.
  String get encryptionAlgorithm =>
      getState(EventTypes.Encryption)?.parsedRoomEncryptionContent?.algorithm;

  /// Checks if this room is encrypted.
  bool get encrypted => encryptionAlgorithm != null;

  Future<void> enableEncryption({int algorithmIndex = 0}) async {
    if (encrypted) throw ('Encryption is already enabled!');
    final algorithm = Client.supportedGroupEncryptionAlgorithms[algorithmIndex];
    await client.setRoomStateWithKey(
      id,
      EventTypes.Encryption,
      '',
      {
        'algorithm': algorithm,
      },
    );
    return;
  }

  /// Returns all known device keys for all participants in this room.
  Future<List<DeviceKeys>> getUserDeviceKeys() async {
    final deviceKeys = <DeviceKeys>[];
    final users = await requestParticipants();
    for (final user in users) {
      if ([Membership.invite, Membership.join].contains(user.membership) &&
          client.userDeviceKeys.containsKey(user.id)) {
        for (final deviceKeyEntry
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

  Future<void> _handleFakeSync(SyncUpdate syncUpdate,
      {bool sortAtTheEnd = false}) async {
    if (client.database != null) {
      await client.database.transaction(() async {
        await client.handleSync(syncUpdate, sortAtTheEnd: sortAtTheEnd);
      });
    } else {
      await client.handleSync(syncUpdate, sortAtTheEnd: sortAtTheEnd);
    }
  }

  /// Whether this is an extinct room which has been archived in favor of a new
  /// room which replaces this. Use `getLegacyRoomInformations()` to get more
  /// informations about it if this is true.
  bool get isExtinct => getState(EventTypes.RoomTombstone) != null;

  /// Returns informations about how this room is
  TombstoneContent get extinctInformations => isExtinct
      ? getState(EventTypes.RoomTombstone).parsedTombstoneContent
      : null;

  /// Checks if the `m.room.create` state has a `type` key with the value
  /// `m.space`.
  bool get isSpace =>
      getState(EventTypes.RoomCreate)?.content?.tryGet<String>('type') ==
      RoomCreationTypes.mSpace; // TODO: Magic string!

  /// The parents of this room. Currently this SDK doesn't yet set the canonical
  /// flag and is not checking if this room is in fact a child of this space.
  /// You should therefore not rely on this and always check the children of
  /// the space.
  List<SpaceParent> get spaceParents =>
      states[EventTypes.spaceParent]
          ?.values
          ?.map((state) => SpaceParent.fromState(state))
          ?.where((child) => child.via?.isNotEmpty ?? false)
          ?.toList() ??
      [];

  /// List all children of this space. Children without a `via` domain will be
  /// ignored.
  /// Children are sorted by the `order` while those without this field will be
  /// sorted at the end of the list.
  List<SpaceChild> get spaceChildren => !isSpace
      ? throw Exception('Room is not a space!')
      : (states[EventTypes.spaceChild]
              ?.values
              ?.map((state) => SpaceChild.fromState(state))
              ?.where((child) => child.via?.isNotEmpty ?? false)
              ?.toList() ??
          [])
    ..sort((a, b) => a.order.isEmpty || b.order.isEmpty
        ? b.order.compareTo(a.order)
        : a.order.compareTo(b.order));

  /// Adds or edits a child of this space.
  Future<void> setSpaceChild(
    String roomId, {
    List<String> via,
    String order,
    bool suggested,
  }) async {
    if (!isSpace) throw Exception('Room is not a space!');
    via ??= [roomId.domain];
    await client.setRoomStateWithKey(id, EventTypes.spaceChild, roomId, {
      'via': via,
      if (order != null) 'order': order,
      if (suggested != null) 'suggested': suggested,
    });
    await client.setRoomStateWithKey(roomId, EventTypes.spaceParent, id, {
      'via': via,
    });
    return;
  }

  /// Remove a child from this space by setting the `via` to an empty list.
  Future<void> removeSpaceChild(String roomId) => !isSpace
      ? throw Exception('Room is not a space!')
      : setSpaceChild(roomId, via: const []);

  @override
  bool operator ==(dynamic other) => (other is Room && other.id == id);
}
