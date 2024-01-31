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
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:html_unescape/html_unescape.dart';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/models/timeline_chunk.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:matrix/src/utils/crypto/crypto.dart';
import 'package:matrix/src/utils/file_send_request_credentials.dart';
import 'package:matrix/src/utils/markdown.dart';
import 'package:matrix/src/utils/marked_unread.dart';
import 'package:matrix/src/utils/space_child.dart';

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

const String fileSendingStatusKey =
    'com.famedly.famedlysdk.file_sending_status';

const String emptyRoomName = 'Empty chat';

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
  String? prev_batch;

  RoomSummary summary;

  /// The room states are a key value store of the key (`type`,`state_key`) => State(event).
  /// In a lot of cases the `state_key` might be an empty string. You **should** use the
  /// methods `getState()` and `setState()` to interact with the room states.
  Map<String, Map<String, Event>> states = {};

  /// Key-Value store for ephemerals.
  Map<String, BasicRoomEvent> ephemerals = {};

  /// Key-Value store for private account data only visible for this user.
  Map<String, BasicRoomEvent> roomAccountData = {};

  final _sendingQueue = <Completer>[];

  Map<String, dynamic> toJson() => {
        'id': id,
        'membership': membership.toString().split('.').last,
        'highlight_count': highlightCount,
        'notification_count': notificationCount,
        'prev_batch': prev_batch,
        'summary': summary.toJson(),
      };

  factory Room.fromJson(Map<String, dynamic> json, Client client) => Room(
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
      );

  /// Flag if the room is partial, meaning not all state events have been loaded yet
  bool partial = true;

  /// Post-loads the room.
  /// This load all the missing state events for the room from the database
  /// If the room has already been loaded, this does nothing.
  Future<void> postLoad() async {
    if (!partial) {
      return;
    }
    final allStates = await client.database
        ?.getUnimportantRoomEventStatesForRoom(
            client.importantStateEvents.toList(), this);

    if (allStates != null) {
      for (final state in allStates) {
        setState(state);
      }
    }
    partial = false;
  }

  /// Returns the [Event] for the given [typeKey] and optional [stateKey].
  /// If no [stateKey] is provided, it defaults to an empty string.
  Event? getState(String typeKey, [String stateKey = '']) =>
      states[typeKey]?[stateKey];

  /// Adds the [state] to this room and overwrites a state with the same
  /// typeKey/stateKey key pair if there is one.
  void setState(Event state) {
    // Decrypt if necessary
    if (state.type == EventTypes.Encrypted && client.encryptionEnabled) {
      try {
        state = client.encryption?.decryptRoomEventSync(id, state) ?? state;
      } catch (e, s) {
        Logs().e('[LibOlm] Could not decrypt room state', e, s);
      }
    }

    // We ignore room verification events for lastEvents
    if (state.type == EventTypes.Message &&
        state.messageType.startsWith('m.room.verification.')) {
      return;
    }

    final isMessageEvent = {
      EventTypes.Message,
      EventTypes.Encrypted,
      EventTypes.Sticker
    }.contains(state.type);

    // We ignore events editing events older than the current-latest here so
    // i.e. newly sent edits for older events don't show up in room preview
    final lastEvent = this.lastEvent;
    if (isMessageEvent &&
        state.relationshipEventId != null &&
        state.relationshipType == RelationshipTypes.edit &&
        lastEvent != null &&
        !state.matchesEventOrTransactionId(lastEvent.eventId) &&
        lastEvent.eventId != state.relationshipEventId &&
        !(lastEvent.relationshipType == RelationshipTypes.edit &&
            lastEvent.relationshipEventId == state.relationshipEventId)) {
      return;
    }

    // Ignore other non-state events
    final stateKey = state.stateKey ??
        (client.roomPreviewLastEvents.contains(state.type) ? '' : null);
    final roomId = state.roomId;
    if (stateKey == null || roomId == null) {
      return;
    }

    // Do not set old events as state events
    final prevEvent = getState(state.type, stateKey);
    if (prevEvent != null &&
        prevEvent.eventId != state.eventId &&
        prevEvent.originServerTs.millisecondsSinceEpoch >
            state.originServerTs.millisecondsSinceEpoch) {
      return;
    }

    (states[state.type] ??= {})[stateKey] = state;

    client.onRoomState.add(state);
  }

  /// ID of the fully read marker event.
  String get fullyRead =>
      roomAccountData['m.fully_read']?.content.tryGet<String>('event_id') ?? '';

  /// If something changes, this callback will be triggered. Will return the
  /// room id.
  final CachedStreamController<String> onUpdate = CachedStreamController();

  /// If there is a new session key received, this will be triggered with
  /// the session ID.
  final CachedStreamController<String> onSessionKeyReceived =
      CachedStreamController();

  /// The name of the room if set by a participant.
  String get name {
    final n = getState(EventTypes.RoomName)?.content['name'];
    return (n is String) ? n : '';
  }

  /// The pinned events for this room. If there are none this returns an empty
  /// list.
  List<String> get pinnedEventIds {
    final pinned = getState(EventTypes.RoomPinnedEvents)?.content['pinned'];
    return pinned is Iterable ? pinned.map((e) => e.toString()).toList() : [];
  }

  /// Returns the heroes as `User` objects.
  /// This is very useful if you want to make sure that all users are loaded
  /// from the database, that you need to correctly calculate the displayname
  /// and the avatar of the room.
  Future<List<User>> loadHeroUsers() async {
    var heroes = summary.mHeroes;
    if (heroes == null) {
      final directChatMatrixID = this.directChatMatrixID;
      if (directChatMatrixID != null) {
        heroes = [directChatMatrixID];
      }
    }

    if (heroes == null) return [];

    return await Future.wait(heroes.map((hero) async =>
        (await requestUser(
          hero,
          ignoreErrors: true,
        )) ??
        User(hero, room: this)));
  }

  /// Returns a localized displayname for this server. If the room is a groupchat
  /// without a name, then it will return the localized version of 'Group with Alice' instead
  /// of just 'Alice' to make it different to a direct chat.
  /// Empty chats will become the localized version of 'Empty Chat'.
  /// This method requires a localization class which implements [MatrixLocalizations]
  String getLocalizedDisplayname([
    MatrixLocalizations i18n = const MatrixDefaultLocalizations(),
  ]) {
    if (name.isNotEmpty) return name;

    final canonicalAlias = this.canonicalAlias.localpart;
    if (canonicalAlias != null && canonicalAlias.isNotEmpty) {
      return canonicalAlias;
    }

    final directChatMatrixID = this.directChatMatrixID;
    final heroes = summary.mHeroes ??
        (directChatMatrixID == null ? [] : [directChatMatrixID]);
    if (heroes.isNotEmpty) {
      final result = heroes
          .where(
            // removing oneself from the hero list
            (hero) => hero.isNotEmpty && hero != client.userID,
          )
          .map((hero) => unsafeGetUserFromMemoryOrFallback(hero)
              .calcDisplayname(i18n: i18n))
          .join(', ');
      if (isAbandonedDMRoom) {
        return i18n.wasDirectChatDisplayName(result);
      }

      return isDirectChat ? result : i18n.groupWith(result);
    }
    if (membership == Membership.invite) {
      final sender = getState(EventTypes.RoomMember, client.userID!)
          ?.senderFromMemoryOrFallback
          .calcDisplayname(i18n: i18n);
      if (sender != null) return sender;
    }
    if (membership == Membership.leave) {
      final invitation = getState(EventTypes.RoomMember, client.userID!);
      if (invitation != null &&
          invitation.unsigned?.tryGet<String>('prev_sender') != null) {
        final name = unsafeGetUserFromMemoryOrFallback(
                invitation.unsigned!.tryGet<String>('prev_sender')!)
            .calcDisplayname(i18n: i18n);
        return i18n.wasDirectChatDisplayName(name);
      }
    }
    return i18n.emptyChat;
  }

  /// The topic of the room if set by a participant.
  String get topic {
    final t = getState(EventTypes.RoomTopic)?.content['topic'];
    return t is String ? t : '';
  }

  /// The avatar of the room if set by a participant.
  Uri? get avatar {
    final avatarUrl = getState(EventTypes.RoomAvatar)?.content['url'];
    if (avatarUrl is String) {
      return Uri.tryParse(avatarUrl);
    }

    final heroes = summary.mHeroes;
    if (heroes != null && heroes.length == 1) {
      final hero = getState(EventTypes.RoomMember, heroes.first);
      if (hero != null) {
        return hero.asUser.avatarUrl;
      }
    }
    if (isDirectChat) {
      final user = directChatMatrixID;
      if (user != null) {
        return unsafeGetUserFromMemoryOrFallback(user).avatarUrl;
      }
    }
    if (membership == Membership.invite) {
      final userID = client.userID;
      if (userID == null) return null;
      return getState(EventTypes.RoomMember, userID)
          ?.senderFromMemoryOrFallback
          .avatarUrl;
    }
    return null;
  }

  /// The address in the format: #roomname:homeserver.org.
  String get canonicalAlias {
    final alias = getState(EventTypes.RoomCanonicalAlias)?.content['alias'];
    return (alias is String) ? alias : '';
  }

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
  String? get directChatMatrixID {
    if (membership == Membership.invite) {
      final userID = client.userID;
      if (userID == null) return null;
      final invitation = getState(EventTypes.RoomMember, userID);
      if (invitation != null && invitation.content['is_direct'] == true) {
        return invitation.senderId;
      }
    }

    final mxId = client.directChats.entries
        .firstWhereOrNull((MapEntry<String, dynamic> e) {
      final roomIds = e.value;
      return roomIds is List<dynamic> && roomIds.contains(id);
    })?.key;
    if (mxId?.isValidMatrixId == true) return mxId;
    return null;
  }

  /// Wheither this is a direct chat or not
  bool get isDirectChat => directChatMatrixID != null;

  /// Must be one of [all, mention]
  String? notificationSettings;

  Event? get lastEvent {
    // as lastEvent calculation is based on the state events we unfortunately cannot
    // use sortOrder here: With many state events we just know which ones are the
    // newest ones, without knowing in which order they actually happened. As such,
    // using the origin_server_ts is the best guess for this algorithm. While not
    // perfect, it is only used for the room preview in the room list and sorting
    // said room list, so it should be good enough.
    var lastTime = DateTime.fromMillisecondsSinceEpoch(0);
    final lastEvents =
        client.roomPreviewLastEvents.map(getState).whereType<Event>();

    var lastEvent = lastEvents.isEmpty
        ? null
        : lastEvents.reduce((a, b) {
            if (a.originServerTs == b.originServerTs) {
              // if two events have the same sort order we want to give encrypted events a lower priority
              // This is so that if the same event exists in the state both encrypted *and* unencrypted,
              // the unencrypted one is picked
              return a.type == EventTypes.Encrypted ? b : a;
            }
            return a.originServerTs.millisecondsSinceEpoch >
                    b.originServerTs.millisecondsSinceEpoch
                ? a
                : b;
          });
    if (lastEvent == null) {
      states.forEach((final String key, final entry) {
        final state = entry[''];
        if (state == null) return;
        if (state.originServerTs.millisecondsSinceEpoch >
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
    final typingMxid = ephemerals['m.typing']?.content['user_ids'];
    return (typingMxid is List)
        ? typingMxid
            .cast<String>()
            .map(unsafeGetUserFromMemoryOrFallback)
            .toList()
        : [];
  }

  /// Your current client instance.
  final Client client;

  Room({
    required this.id,
    this.membership = Membership.join,
    this.notificationCount = 0,
    this.highlightCount = 0,
    this.prev_batch,
    required this.client,
    this.notificationSettings,
    Map<String, BasicRoomEvent>? roomAccountData,
    RoomSummary? summary,
  })  : roomAccountData = roomAccountData ?? <String, BasicRoomEvent>{},
        summary = summary ??
            RoomSummary.fromJson({
              'm.joined_member_count': 0,
              'm.invited_member_count': 0,
              'm.heroes': [],
            });

  /// The default count of how much events should be requested when requesting the
  /// history of this room.
  static const int defaultHistoryCount = 30;

  /// Checks if this is an abandoned DM room where the other participant has
  /// left the room. This is false when there are still other users in the room
  /// or the room is not marked as a DM room.
  bool get isAbandonedDMRoom {
    final directChatMatrixID = this.directChatMatrixID;

    if (directChatMatrixID == null) return false;
    final dmPartnerMembership =
        unsafeGetUserFromMemoryOrFallback(directChatMatrixID).membership;
    return dmPartnerMembership == Membership.leave &&
        summary.mJoinedMemberCount == 1 &&
        summary.mInvitedMemberCount == 0;
  }

  /// Calculates the displayname. First checks if there is a name, then checks for a canonical alias and
  /// then generates a name from the heroes.
  @Deprecated('Use `getLocalizedDisplayname()` instead')
  String get displayname => getLocalizedDisplayname();

  /// When the last message received.
  DateTime get timeCreated => lastEvent?.originServerTs ?? DateTime.now();

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
  Future<void> addTag(String tag, {double? order}) => client.setRoomTag(
        client.userID!,
        id,
        tag,
        order: order,
      );

  /// Removes a tag from the room.
  Future<void> removeTag(String tag) => client.deleteRoomTag(
        client.userID!,
        id,
        tag,
      );

  // Tag is part of client-to-server-API, so it uses strict parsing.
  // For roomAccountData, permissive parsing is more suitable,
  // so it is implemented here.
  static Tag _tryTagFromJson(Object o) {
    if (o is Map<String, dynamic>) {
      return Tag(
          order: o.tryGet<num>('order', TryGet.silent)?.toDouble(),
          additionalProperties: Map.from(o)..remove('order'));
    }
    return Tag();
  }

  /// Returns all tags for this room.
  Map<String, Tag> get tags {
    final tags = roomAccountData['m.tag']?.content['tags'];

    if (tags is Map) {
      final parsedTags =
          tags.map((k, v) => MapEntry<String, Tag>(k, _tryTagFromJson(v)));
      parsedTags.removeWhere((k, v) => !TagType.isValid(k));
      return parsedTags;
    }

    return {};
  }

  bool get markedUnread {
    return MarkedUnread.fromJson(
            roomAccountData[EventType.markedUnread]?.content ?? {})
        .unread;
  }

  /// Checks if the last event has a read marker of the user.
  /// Warning: This compares the origin server timestamp which might not map
  /// to the real sort order of the timeline.
  bool get hasNewMessages {
    final lastEvent = this.lastEvent;

    // There is no known event or the last event is only a state fallback event,
    // we assume there is no new messages.
    if (lastEvent == null ||
        !client.roomPreviewLastEvents.contains(lastEvent.type)) return false;

    // Read marker is on the last event so no new messages.
    if (lastEvent.receipts
        .any((receipt) => receipt.user.senderId == client.userID!)) {
      return false;
    }

    // If the last event is sent, we mark the room as read.
    if (lastEvent.senderId == client.userID) return false;

    // Get the timestamp of read marker and compare
    final readAtMilliseconds = receiptState.global.latestOwnReceipt?.ts ?? 0;
    return readAtMilliseconds < lastEvent.originServerTs.millisecondsSinceEpoch;
  }

  LatestReceiptState get receiptState => LatestReceiptState.fromJson(
      roomAccountData[LatestReceiptState.eventType]?.content ??
          <String, dynamic>{});

  /// Returns true if this room is unread. To check if there are new messages
  /// in muted rooms, use [hasNewMessages].
  bool get isUnread => notificationCount > 0 || markedUnread;

  /// Returns true if this room is to be marked as unread. This extends
  /// [isUnread] to rooms with [Membership.invite].
  bool get isUnreadOrInvited => isUnread || membership == Membership.invite;

  @Deprecated('Use waitForRoomInSync() instead')
  Future<SyncUpdate> get waitForSync => waitForRoomInSync();

  /// Wait for the room to appear in join, leave or invited section of the
  /// sync.
  Future<SyncUpdate> waitForRoomInSync() async {
    return await client.waitForRoomInSync(id);
  }

  /// Sets an unread flag manually for this room. This changes the local account
  /// data model before syncing it to make sure
  /// this works if there is no connection to the homeserver. This does **not**
  /// set a read marker!
  Future<void> markUnread(bool unread) async {
    final content = MarkedUnread(unread).toJson();
    await _handleFakeSync(
      SyncUpdate(
        nextBatch: '',
        rooms: RoomsUpdate(
          join: {
            id: JoinedRoomUpdate(
              accountData: [
                BasicRoomEvent(
                  content: content,
                  roomId: id,
                  type: EventType.markedUnread,
                ),
              ],
            )
          },
        ),
      ),
    );
    await client.setAccountDataPerRoom(
      client.userID!,
      id,
      EventType.markedUnread,
      content,
    );
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

  /// returns the resolved mxid for a mention string, or null if none found
  String? getMention(String mention) => getParticipants()
      .firstWhereOrNull((u) => u.mentionFragments.contains(mention))
      ?.id;

  /// Sends a normal text message to this room. Returns the event ID generated
  /// by the server for this message.
  Future<String?> sendTextEvent(String message,
      {String? txid,
      Event? inReplyTo,
      String? editEventId,
      bool parseMarkdown = true,
      bool parseCommands = true,
      String msgtype = MessageTypes.Text,
      String? threadRootEventId,
      String? threadLastEventId}) {
    if (parseCommands) {
      return client.parseAndRunCommand(this, message,
          inReplyTo: inReplyTo,
          editEventId: editEventId,
          txid: txid,
          threadRootEventId: threadRootEventId,
          threadLastEventId: threadLastEventId);
    }
    final event = <String, dynamic>{
      'msgtype': msgtype,
      'body': message,
    };
    if (parseMarkdown) {
      final html = markdown(event['body'],
          getEmotePacks: () => getImagePacksFlat(ImagePackUsage.emoticon),
          getMention: getMention);
      // if the decoded html is the same as the body, there is no need in sending a formatted message
      if (HtmlUnescape().convert(html.replaceAll(RegExp(r'<br />\n?'), '\n')) !=
          event['body']) {
        event['format'] = 'org.matrix.custom.html';
        event['formatted_body'] = html;
      }
    }
    return sendEvent(event,
        txid: txid,
        inReplyTo: inReplyTo,
        editEventId: editEventId,
        threadRootEventId: threadRootEventId,
        threadLastEventId: threadLastEventId);
  }

  /// Sends a reaction to an event with an [eventId] and the content [key] into a room.
  /// Returns the event ID generated by the server for this reaction.
  Future<String?> sendReaction(String eventId, String key, {String? txid}) {
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
  Future<String?> sendLocation(String body, String geoUri, {String? txid}) {
    final event = <String, dynamic>{
      'msgtype': 'm.location',
      'body': body,
      'geo_uri': geoUri,
    };
    return sendEvent(event, txid: txid);
  }

  final Map<String, MatrixFile> sendingFilePlaceholders = {};
  final Map<String, MatrixImageFile> sendingFileThumbnails = {};

  /// Sends a [file] to this room after uploading it. Returns the mxc uri of
  /// the uploaded file. If [waitUntilSent] is true, the future will wait until
  /// the message event has received the server. Otherwise the future will only
  /// wait until the file has been uploaded.
  /// Optionally specify [extraContent] to tack on to the event.
  ///
  /// In case [file] is a [MatrixImageFile], [thumbnail] is automatically
  /// computed unless it is explicitly provided.
  /// Set [shrinkImageMaxDimension] to for example `1600` if you want to shrink
  /// your image before sending. This is ignored if the File is not a
  /// [MatrixImageFile].
  Future<String?> sendFileEvent(
    MatrixFile file, {
    String? txid,
    Event? inReplyTo,
    String? editEventId,
    int? shrinkImageMaxDimension,
    MatrixImageFile? thumbnail,
    Map<String, dynamic>? extraContent,
    String? threadRootEventId,
    String? threadLastEventId,
  }) async {
    txid ??= client.generateUniqueTransactionId();
    sendingFilePlaceholders[txid] = file;
    if (thumbnail != null) {
      sendingFileThumbnails[txid] = thumbnail;
    }

    // Create a fake Event object as a placeholder for the uploading file:
    final syncUpdate = SyncUpdate(
      nextBatch: '',
      rooms: RoomsUpdate(
        join: {
          id: JoinedRoomUpdate(
            timeline: TimelineUpdate(
              events: [
                MatrixEvent(
                  content: {
                    'msgtype': file.msgType,
                    'body': file.name,
                    'filename': file.name,
                  },
                  type: EventTypes.Message,
                  eventId: txid,
                  senderId: client.userID!,
                  originServerTs: DateTime.now(),
                  unsigned: {
                    messageSendingStatusKey: EventStatus.sending.intValue,
                    'transaction_id': txid,
                    ...FileSendRequestCredentials(
                      inReplyTo: inReplyTo?.eventId,
                      editEventId: editEventId,
                      shrinkImageMaxDimension: shrinkImageMaxDimension,
                      extraContent: extraContent,
                    ).toJson(),
                  },
                ),
              ],
            ),
          ),
        },
      ),
    );

    MatrixFile uploadFile = file; // ignore: omit_local_variable_types
    // computing the thumbnail in case we can
    if (file is MatrixImageFile &&
        (thumbnail == null || shrinkImageMaxDimension != null)) {
      syncUpdate.rooms!.join!.values.first.timeline!.events!.first
              .unsigned![fileSendingStatusKey] =
          FileSendingStatus.generatingThumbnail.name;
      await _handleFakeSync(syncUpdate);
      thumbnail ??= await file.generateThumbnail(
        nativeImplementations: client.nativeImplementations,
        customImageResizer: client.customImageResizer,
      );
      if (shrinkImageMaxDimension != null) {
        file = await MatrixImageFile.shrink(
          bytes: file.bytes,
          name: file.name,
          maxDimension: shrinkImageMaxDimension,
          customImageResizer: client.customImageResizer,
          nativeImplementations: client.nativeImplementations,
        );
      }

      if (thumbnail != null && file.size < thumbnail.size) {
        thumbnail = null; // in this case, the thumbnail is not usefull
      }
    }

    // Check media config of the server before sending the file. Stop if the
    // Media config is unreachable or the file is bigger than the given maxsize.
    try {
      final mediaConfig = await client.getConfig();
      final maxMediaSize = mediaConfig.mUploadSize;
      if (maxMediaSize != null && maxMediaSize < file.bytes.lengthInBytes) {
        throw FileTooBigMatrixException(file.bytes.lengthInBytes, maxMediaSize);
      }
    } catch (e) {
      Logs().d('Config error while sending file', e);
      syncUpdate.rooms!.join!.values.first.timeline!.events!.first
          .unsigned![messageSendingStatusKey] = EventStatus.error.intValue;
      await _handleFakeSync(syncUpdate);
      rethrow;
    }

    MatrixFile? uploadThumbnail =
        thumbnail; // ignore: omit_local_variable_types
    EncryptedFile? encryptedFile;
    EncryptedFile? encryptedThumbnail;
    if (encrypted && client.fileEncryptionEnabled) {
      syncUpdate.rooms!.join!.values.first.timeline!.events!.first
          .unsigned![fileSendingStatusKey] = FileSendingStatus.encrypting.name;
      await _handleFakeSync(syncUpdate);
      encryptedFile = await file.encrypt();
      uploadFile = encryptedFile.toMatrixFile();

      if (thumbnail != null) {
        encryptedThumbnail = await thumbnail.encrypt();
        uploadThumbnail = encryptedThumbnail.toMatrixFile();
      }
    }
    Uri? uploadResp, thumbnailUploadResp;

    final timeoutDate = DateTime.now().add(client.sendTimelineEventTimeout);

    syncUpdate.rooms!.join!.values.first.timeline!.events!.first
        .unsigned![fileSendingStatusKey] = FileSendingStatus.uploading.name;
    while (uploadResp == null ||
        (uploadThumbnail != null && thumbnailUploadResp == null)) {
      try {
        uploadResp = await client.uploadContent(
          uploadFile.bytes,
          filename: uploadFile.name,
          contentType: uploadFile.mimeType,
        );
        thumbnailUploadResp = uploadThumbnail != null
            ? await client.uploadContent(
                uploadThumbnail.bytes,
                filename: uploadThumbnail.name,
                contentType: uploadThumbnail.mimeType,
              )
            : null;
      } on MatrixException catch (_) {
        syncUpdate.rooms!.join!.values.first.timeline!.events!.first
            .unsigned![messageSendingStatusKey] = EventStatus.error.intValue;
        await _handleFakeSync(syncUpdate);
        rethrow;
      } catch (_) {
        if (DateTime.now().isAfter(timeoutDate)) {
          syncUpdate.rooms!.join!.values.first.timeline!.events!.first
              .unsigned![messageSendingStatusKey] = EventStatus.error.intValue;
          await _handleFakeSync(syncUpdate);
          rethrow;
        }
        Logs().v('Send File into room failed. Try again...');
        await Future.delayed(Duration(seconds: 1));
      }
    }

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
          'thumbnail_url': thumbnailUploadResp.toString(),
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
        if (thumbnail?.blurhash != null &&
            file is MatrixImageFile &&
            file.blurhash == null)
          'xyz.amorgan.blurhash': thumbnail!.blurhash
      },
      if (extraContent != null) ...extraContent,
    };
    final eventId = await sendEvent(
      content,
      txid: txid,
      inReplyTo: inReplyTo,
      editEventId: editEventId,
      threadRootEventId: threadRootEventId,
      threadLastEventId: threadLastEventId,
    );
    sendingFilePlaceholders.remove(txid);
    sendingFileThumbnails.remove(txid);
    return eventId;
  }

  /// Calculates how secure the communication is. When all devices are blocked or
  /// verified, then this returns [EncryptionHealthState.allVerified]. When at
  /// least one device is not verified, then it returns
  /// [EncryptionHealthState.unverifiedDevices]. Apps should display this health
  /// state next to the input text field to inform the user about the current
  /// encryption security level.
  Future<EncryptionHealthState> calcEncryptionHealthState() async {
    final users = await requestParticipants();
    users.removeWhere((u) =>
        !{Membership.invite, Membership.join}.contains(u.membership) ||
        !client.userDeviceKeys.containsKey(u.id));

    if (users.any((u) =>
        client.userDeviceKeys[u.id]!.verified != UserVerifiedStatus.verified)) {
      return EncryptionHealthState.unverifiedDevices;
    }

    return EncryptionHealthState.allVerified;
  }

  Future<String?> _sendContent(
    String type,
    Map<String, dynamic> content, {
    String? txid,
  }) async {
    txid ??= client.generateUniqueTransactionId();

    final mustEncrypt = encrypted && client.encryptionEnabled;

    final sendMessageContent = mustEncrypt
        ? await client.encryption!
            .encryptGroupMessagePayload(id, content, type: type)
        : content;
    return await client.sendMessage(
      id,
      sendMessageContent.containsKey('ciphertext')
          ? EventTypes.Encrypted
          : type,
      txid,
      sendMessageContent,
    );
  }

  String _stripBodyFallback(String body) {
    if (body.startsWith('> <@')) {
      var temp = '';
      var inPrefix = true;
      for (final l in body.split('\n')) {
        if (inPrefix && (l.isEmpty || l.startsWith('> '))) {
          continue;
        }

        inPrefix = false;
        temp += temp.isEmpty ? l : ('\n$l');
      }

      return temp;
    } else {
      return body;
    }
  }

  /// Sends an event to this room with this json as a content. Returns the
  /// event ID generated from the server.
  /// It uses list of completer to make sure events are sending in a row.
  Future<String?> sendEvent(
    Map<String, dynamic> content, {
    String type = EventTypes.Message,
    String? txid,
    Event? inReplyTo,
    String? editEventId,
    String? threadRootEventId,
    String? threadLastEventId,
  }) async {
    // Create new transaction id
    final String messageID;
    if (txid == null) {
      messageID = client.generateUniqueTransactionId();
    } else {
      messageID = txid;
    }

    if (inReplyTo != null) {
      var replyText =
          '<${inReplyTo.senderId}> ${_stripBodyFallback(inReplyTo.body)}';
      replyText = replyText.split('\n').map((line) => '> $line').join('\n');
      content['format'] = 'org.matrix.custom.html';
      // be sure that we strip any previous reply fallbacks
      final replyHtml = (inReplyTo.formattedText.isNotEmpty
              ? inReplyTo.formattedText
              : htmlEscape.convert(inReplyTo.body).replaceAll('\n', '<br>'))
          .replaceAll(
              RegExp(r'<mx-reply>.*</mx-reply>',
                  caseSensitive: false, multiLine: false, dotAll: true),
              '');
      final repliedHtml = content.tryGet<String>('formatted_body') ??
          htmlEscape
              .convert(content.tryGet<String>('body') ?? '')
              .replaceAll('\n', '<br>');
      content['formatted_body'] =
          '<mx-reply><blockquote><a href="https://matrix.to/#/${inReplyTo.roomId!}/${inReplyTo.eventId}">In reply to</a> <a href="https://matrix.to/#/${inReplyTo.senderId}">${inReplyTo.senderId}</a><br>$replyHtml</blockquote></mx-reply>$repliedHtml';
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

    if (threadRootEventId != null) {
      content['m.relates_to'] = {
        'event_id': threadRootEventId,
        'rel_type': RelationshipTypes.thread,
        'is_falling_back': inReplyTo == null,
        if (inReplyTo != null) ...{
          'm.in_reply_to': {
            'event_id': inReplyTo.eventId,
          },
        } else ...{
          if (threadLastEventId != null)
            'm.in_reply_to': {
              'event_id': threadLastEventId,
            },
        }
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
        content['body'] = '* ${content['body']}';
      }
      if (content['formatted_body'] is String) {
        content['formatted_body'] = '* ${content['formatted_body']}';
      }
    }
    final sentDate = DateTime.now();
    final syncUpdate = SyncUpdate(
      nextBatch: '',
      rooms: RoomsUpdate(
        join: {
          id: JoinedRoomUpdate(
            timeline: TimelineUpdate(
              events: [
                MatrixEvent(
                  content: content,
                  type: type,
                  eventId: messageID,
                  senderId: client.userID!,
                  originServerTs: sentDate,
                  unsigned: {
                    messageSendingStatusKey: EventStatus.sending.intValue,
                    'transaction_id': messageID,
                  },
                ),
              ],
            ),
          ),
        },
      ),
    );
    await _handleFakeSync(syncUpdate);
    final completer = Completer();
    _sendingQueue.add(completer);
    while (_sendingQueue.first != completer) {
      await _sendingQueue.first.future;
    }

    final timeoutDate = DateTime.now().add(client.sendTimelineEventTimeout);
    // Send the text and on success, store and display a *sent* event.
    String? res;

    while (res == null) {
      try {
        res = await _sendContent(
          type,
          content,
          txid: messageID,
        );
      } catch (e, s) {
        if (e is MatrixException &&
            e.retryAfterMs != null &&
            !DateTime.now()
                .add(Duration(milliseconds: e.retryAfterMs!))
                .isAfter(timeoutDate)) {
          Logs().w(
              'Ratelimited while sending message, waiting for ${e.retryAfterMs}ms');
          await Future.delayed(Duration(milliseconds: e.retryAfterMs!));
        } else if (e is MatrixException ||
            DateTime.now().isAfter(timeoutDate)) {
          Logs().w('Problem while sending message', e, s);
          syncUpdate.rooms!.join!.values.first.timeline!.events!.first
              .unsigned![messageSendingStatusKey] = EventStatus.error.intValue;
          await _handleFakeSync(syncUpdate);
          completer.complete();
          _sendingQueue.remove(completer);
          return null;
        } else {
          Logs()
              .w('Problem while sending message: $e Try again in 1 seconds...');
          await Future.delayed(Duration(seconds: 1));
        }
      }
    }
    syncUpdate.rooms!.join!.values.first.timeline!.events!.first
        .unsigned![messageSendingStatusKey] = EventStatus.sent.intValue;
    syncUpdate.rooms!.join!.values.first.timeline!.events!.first.eventId = res;
    await _handleFakeSync(syncUpdate);
    completer.complete();
    _sendingQueue.remove(completer);

    return res;
  }

  /// Call the Matrix API to join this room if the user is not already a member.
  /// If this room is intended to be a direct chat, the direct chat flag will
  /// automatically be set.
  Future<void> join({bool leaveIfNotFound = true}) async {
    try {
      // If this is a DM, mark it as a DM first, because otherwise the current member
      // event might be the join event already and there is also a race condition there for SDK users.
      final dmId = directChatMatrixID;
      if (dmId != null) {
        await addToDirectChat(dmId);
      }

      // now join
      await client.joinRoomById(id);
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
    try {
      await client.leaveRoom(id);
    } on MatrixException catch (exception) {
      if ([MatrixError.M_NOT_FOUND, MatrixError.M_UNKNOWN]
          .contains(exception.error)) {
        await _handleFakeSync(
          SyncUpdate(
            nextBatch: '',
            rooms: RoomsUpdate(
              leave: {
                id: LeftRoomUpdate(),
              },
            ),
          ),
        );
      }
      rethrow;
    }
    return;
  }

  /// Call the Matrix API to forget this room if you already left it.
  Future<void> forget() async {
    await client.database?.forgetRoom(id);
    await client.forgetRoom(id);
    // Update archived rooms, otherwise an archived room may still be in the
    // list after a forget room call
    final roomIndex = client.archivedRooms.indexWhere((r) => r.room.id == id);
    if (roomIndex != -1) {
      client.archivedRooms.removeAt(roomIndex);
    }
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
    var powerMap = getState(EventTypes.RoomPowerLevels)?.content;
    if (powerMap is! Map<String, dynamic>) {
      powerMap = <String, dynamic>{};
    }
    (powerMap['users'] ??= {})[userID] = power;

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
  /// Returns the actual count of received timeline events.
  Future<int> requestHistory(
      {int historyCount = defaultHistoryCount,
      void Function()? onHistoryReceived,
      direction = Direction.b}) async {
    final prev_batch = this.prev_batch;

    final storeInDatabase = !isArchived;

    if (prev_batch == null) {
      throw 'Tried to request history without a prev_batch token';
    }
    final resp = await client.getRoomEvents(
      id,
      direction,
      from: prev_batch,
      limit: historyCount,
      filter: jsonEncode(StateFilter(lazyLoadMembers: true).toJson()),
    );

    if (onHistoryReceived != null) onHistoryReceived();
    this.prev_batch = resp.end;

    Future<void> loadFn() async {
      if (!((resp.chunk.isNotEmpty) && resp.end != null)) return;

      await client.handleSync(
          SyncUpdate(
            nextBatch: '',
            rooms: RoomsUpdate(
                join: membership == Membership.join
                    ? {
                        id: JoinedRoomUpdate(
                          state: resp.state,
                          timeline: TimelineUpdate(
                            limited: false,
                            events: direction == Direction.b
                                ? resp.chunk
                                : resp.chunk.reversed.toList(),
                            prevBatch: direction == Direction.b
                                ? resp.end
                                : resp.start,
                          ),
                        )
                      }
                    : null,
                leave: membership != Membership.join
                    ? {
                        id: LeftRoomUpdate(
                          state: resp.state,
                          timeline: TimelineUpdate(
                            limited: false,
                            events: direction == Direction.b
                                ? resp.chunk
                                : resp.chunk.reversed.toList(),
                            prevBatch: direction == Direction.b
                                ? resp.end
                                : resp.start,
                          ),
                        ),
                      }
                    : null),
          ),
          direction: Direction.b);
    }

    if (client.database != null) {
      await client.database?.transaction(() async {
        if (storeInDatabase) {
          await client.database?.setRoomPrevBatch(resp.end, id, client);
        }
        await loadFn();
      });
    } else {
      await loadFn();
    }

    return resp.chunk.length;
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
      client.userID!,
      'm.direct',
      directChats,
    );
    return;
  }

  /// Removes this room from all direct chat tags.
  Future<void> removeFromDirectChat() async {
    final directChats = client.directChats.copy();
    for (final k in directChats.keys) {
      final directChat = directChats[k];
      if (directChat is List && directChat.contains(id)) {
        directChat.remove(id);
      }
    }

    directChats.removeWhere((_, v) => v is List && v.isEmpty);

    if (directChats == client.directChats) {
      return;
    }

    await client.setAccountData(
      client.userID!,
      'm.direct',
      directChats,
    );
    return;
  }

  /// Get the user fully read marker
  @Deprecated('Use fullyRead marker')
  String? get userFullyReadMarker => fullyRead;

  /// Sets the position of the read marker for a given room, and optionally the
  /// read receipt's location.
  /// If you set `public` to false, only a private receipt will be sent. A private receipt is always sent if `mRead` is set. If no value is provided, the default from the `client` is used.
  /// You can leave out the `eventId`, which will not update the read marker but just send receipts, but there are few cases where that makes sense.
  Future<void> setReadMarker(String? eventId,
      {String? mRead, bool? public}) async {
    await client.setReadMarker(
      id,
      mFullyRead: eventId,
      mRead: (public ?? client.receiptsPublicByDefault) ? mRead : null,
      // we always send the private receipt, because there is no reason not to.
      mReadPrivate: mRead,
    );
    return;
  }

  Future<TimelineChunk?> getEventContext(String eventId) async {
    final resp = await client.getEventContext(id, eventId,
        limit: Room.defaultHistoryCount
        // filter: jsonEncode(StateFilter(lazyLoadMembers: true).toJson()),
        );

    final events = [
      if (resp.eventsAfter != null) ...resp.eventsAfter!.reversed,
      if (resp.event != null) resp.event!,
      if (resp.eventsBefore != null) ...resp.eventsBefore!
    ].map((e) => Event.fromMatrixEvent(e, this)).toList();

    // Try again to decrypt encrypted events but don't update the database.
    if (encrypted && client.database != null && client.encryptionEnabled) {
      for (var i = 0; i < events.length; i++) {
        if (events[i].type == EventTypes.Encrypted &&
            events[i].content['can_request_session'] == true) {
          events[i] = await client.encryption!.decryptRoomEvent(
            id,
            events[i],
          );
        }
      }
    }

    final chunk = TimelineChunk(
        nextBatch: resp.end ?? '', prevBatch: resp.start ?? '', events: events);

    return chunk;
  }

  /// This API updates the marker for the given receipt type to the event ID
  /// specified. In general you want to use `setReadMarker` instead to set private
  /// and public receipt as well as the marker at the same time.
  @Deprecated(
      'Use setReadMarker with mRead set instead. That allows for more control and there are few cases to not send a marker at the same time.')
  Future<void> postReceipt(String eventId,
      {ReceiptType type = ReceiptType.mRead}) async {
    await client.postReceipt(
      id,
      ReceiptType.mRead,
      eventId,
    );
    return;
  }

  /// Is the room archived
  bool get isArchived => membership == Membership.leave;

  /// Creates a timeline from the store. Returns a [Timeline] object. If you
  /// just want to update the whole timeline on every change, use the [onUpdate]
  /// callback. For updating only the parts that have changed, use the
  /// [onChange], [onRemove], [onInsert] and the [onHistoryReceived] callbacks.
  /// This method can also retrieve the timeline at a specific point by setting
  /// the [eventContextId]
  Future<Timeline> getTimeline(
      {void Function(int index)? onChange,
      void Function(int index)? onRemove,
      void Function(int insertID)? onInsert,
      void Function()? onNewEvent,
      void Function()? onUpdate,
      String? eventContextId}) async {
    await postLoad();

    List<Event> events;

    if (!isArchived) {
      events = await client.database?.getEventList(
            this,
            limit: defaultHistoryCount,
          ) ??
          <Event>[];
    } else {
      final archive = client.getArchiveRoomFromCache(id);
      events = archive?.timeline.events.toList() ?? [];
      for (var i = 0; i < events.length; i++) {
        // Try to decrypt encrypted events but don't update the database.
        if (encrypted && client.encryptionEnabled) {
          if (events[i].type == EventTypes.Encrypted) {
            events[i] = await client.encryption!.decryptRoomEvent(
              id,
              events[i],
            );
          }
        }
      }
    }

    var chunk = TimelineChunk(events: events);
    // Load the timeline arround eventContextId if set
    if (eventContextId != null) {
      if (!events.any((Event event) => event.eventId == eventContextId)) {
        chunk =
            await getEventContext(eventContextId) ?? TimelineChunk(events: []);
      }
    }

    final timeline = Timeline(
        room: this,
        chunk: chunk,
        onChange: onChange,
        onRemove: onRemove,
        onInsert: onInsert,
        onNewEvent: onNewEvent,
        onUpdate: onUpdate);

    // Fetch all users from database we have got here.
    if (eventContextId == null) {
      final userIds = events.map((event) => event.senderId).toSet();
      for (final userId in userIds) {
        if (getState(EventTypes.RoomMember, userId) != null) continue;
        final dbUser = await client.database?.getUser(userId, this);
        if (dbUser != null) setState(dbUser);
      }
    }

    // Try again to decrypt encrypted events and update the database.
    if (encrypted && client.encryptionEnabled) {
      // decrypt messages
      for (var i = 0; i < chunk.events.length; i++) {
        if (chunk.events[i].type == EventTypes.Encrypted) {
          if (eventContextId != null) {
            // for the fragmented timeline, we don't cache the decrypted
            //message in the database
            chunk.events[i] = await client.encryption!.decryptRoomEvent(
              id,
              chunk.events[i],
            );
          } else if (client.database != null) {
            // else, we need the database
            await client.database?.transaction(() async {
              for (var i = 0; i < chunk.events.length; i++) {
                if (chunk.events[i].content['can_request_session'] == true) {
                  chunk.events[i] = await client.encryption!.decryptRoomEvent(
                    id,
                    chunk.events[i],
                    store: !isArchived,
                    updateType: EventUpdateType.history,
                  );
                }
              }
            });
          }
        }
      }
    }

    return timeline;
  }

  /// Returns all participants for this room. With lazy loading this
  /// list may not be complete. Use [requestParticipants] in this
  /// case.
  /// List `membershipFilter` defines with what membership do you want the
  /// participants, default set to
  /// [[Membership.join, Membership.invite, Membership.knock]]
  List<User> getParticipants(
      [List<Membership> membershipFilter = const [
        Membership.join,
        Membership.invite,
        Membership.knock,
      ]]) {
    final members = states[EventTypes.RoomMember];
    if (members != null) {
      return members.entries
          .where((entry) => entry.value.type == EventTypes.RoomMember)
          .map((entry) => entry.value.asUser)
          .where((user) => membershipFilter.contains(user.membership))
          .toList();
    }
    return <User>[];
  }

  bool _requestedParticipants = false;

  /// Request the full list of participants from the server. The local list
  /// from the store is not complete if the client uses lazy loading.
  /// List `membershipFilter` defines with what membership do you want the
  /// participants, default set to
  /// [[Membership.join, Membership.invite, Membership.knock]]
  /// Set [cache] to `false` if you do not want to cache the users in memory
  /// for this session which is highly recommended for large public rooms.
  Future<List<User>> requestParticipants(
      [List<Membership> membershipFilter = const [
        Membership.join,
        Membership.invite,
        Membership.knock,
      ],
      bool suppressWarning = false,
      bool cache = true]) async {
    if (!participantListComplete && partial) {
      // we aren't fully loaded, maybe the users are in the database
      final users = await client.database?.getUsers(this) ?? [];
      for (final user in users) {
        setState(user);
      }
    }

    // Do not request users from the server if we have already done it
    // in this session or have a complete list locally.
    if (_requestedParticipants || participantListComplete) {
      return getParticipants(membershipFilter);
    }

    final memberCount = summary.mJoinedMemberCount;
    if (!suppressWarning && cache && memberCount != null && memberCount > 100) {
      Logs().w('''
        Loading a list of $memberCount participants for the room $id.
        This may affect the performance. Please make sure to not unnecessary
        request so many participants or suppress this warning.
      ''');
    }

    final matrixEvents = await client.getMembersByRoom(id);
    final users = matrixEvents
            ?.map((e) => Event.fromMatrixEvent(e, this).asUser)
            .toList() ??
        [];

    if (cache) {
      for (final user in users) {
        setState(user); // at *least* cache this in-memory
      }
    }

    _requestedParticipants = cache;
    users.removeWhere((u) => !membershipFilter.contains(u.membership));
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

  @Deprecated(
      'The method was renamed unsafeGetUserFromMemoryOrFallback. Please prefer requestParticipants.')
  User getUserByMXIDSync(String mxID) {
    return unsafeGetUserFromMemoryOrFallback(mxID);
  }

  /// Returns the [User] object for the given [mxID] or return
  /// a fallback [User] and start a request to get the user
  /// from the homeserver.
  User unsafeGetUserFromMemoryOrFallback(String mxID) {
    final user = getState(EventTypes.RoomMember, mxID);
    if (user != null) {
      return user.asUser;
    } else {
      if (mxID.isValidMatrixId) {
        // ignore: discarded_futures
        requestUser(
          mxID,
          ignoreErrors: true,
          requestProfile: false,
        );
      }
      return User(mxID, room: this);
    }
  }

  final Set<String> _requestingMatrixIds = {};

  /// Requests a missing [User] for this room. Important for clients using
  /// lazy loading. If the user can't be found this method tries to fetch
  /// the displayname and avatar from the profile if [requestProfile] is true.
  Future<User?> requestUser(
    String mxID, {
    bool ignoreErrors = false,
    bool requestProfile = true,
  }) async {
    assert(mxID.isValidMatrixId);

    // Checks if the user is really missing
    final stateUser = getState(EventTypes.RoomMember, mxID);
    if (stateUser != null) {
      return stateUser.asUser;
    }

    // it may be in the database
    final dbuser = await client.database?.getUser(mxID, this);
    if (dbuser != null) {
      setState(dbuser);
      onUpdate.add(id);
      return dbuser;
    }

    if (!_requestingMatrixIds.add(mxID)) return null;
    Map<String, dynamic>? resp;
    try {
      Logs().v(
          'Request missing user $mxID in room ${getLocalizedDisplayname()} from the server...');
      resp = await client.getRoomStateWithKey(
        id,
        EventTypes.RoomMember,
        mxID,
      );
    } on MatrixException catch (_) {
      // Ignore if we have no permission
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
        _requestingMatrixIds.remove(mxID);
        return User(
          mxID,
          displayName: profile.displayname,
          avatarUrl: profile.avatarUrl?.toString(),
          membership: Membership.leave.name,
          room: this,
        );
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
      final fakeEventId = String.fromCharCodes(
        await sha256(
          Uint8List.fromList(
              (id + mxID + client.generateUniqueTransactionId()).codeUnits),
        ),
      );
      await client.database?.storeEventUpdate(
        EventUpdate(
          content: MatrixEvent(
            type: EventTypes.RoomMember,
            content: resp!,
            stateKey: mxID,
            originServerTs: DateTime.now(),
            senderId: mxID,
            eventId: fakeEventId,
          ).toJson(),
          roomID: id,
          type: EventUpdateType.state,
        ),
        client,
      );
    });
    onUpdate.add(id);
    _requestingMatrixIds.remove(mxID);
    return user;
  }

  /// Searches for the event in the local cache and then on the server if not
  /// found. Returns null if not found anywhere.
  Future<Event?> getEventById(String eventID) async {
    try {
      final dbEvent = await client.database?.getEventById(eventID, this);
      if (dbEvent != null) return dbEvent;
      final matrixEvent = await client.getOneRoomEvent(id, eventID);
      final event = Event.fromMatrixEvent(matrixEvent, this);
      if (event.type == EventTypes.Encrypted && client.encryptionEnabled) {
        // attempt decryption
        return await client.encryption?.decryptRoomEvent(
          id,
          event,
        );
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
  /// If a user_id is in the users list, then that user_id has the associated
  /// power level. Otherwise they have the default level users_default.
  /// If users_default is not supplied, it is assumed to be 0. If the room
  /// contains no m.room.power_levels event, the room’s creator has a power
  /// level of 100, and all other users have a power level of 0.
  int getPowerLevelByUserId(String userId) {
    final powerLevelMap = getState(EventTypes.RoomPowerLevels)?.content;

    final userSpecificPowerLevel =
        powerLevelMap?.tryGetMap<String, Object?>('users')?.tryGet<int>(userId);

    final defaultUserPowerLevel = powerLevelMap?.tryGet<int>('users_default');

    final fallbackPowerLevel =
        getState(EventTypes.RoomCreate)?.senderId == userId ? 100 : 0;

    return userSpecificPowerLevel ??
        defaultUserPowerLevel ??
        fallbackPowerLevel;
  }

  /// Returns the user's own power level.
  int get ownPowerLevel => getPowerLevelByUserId(client.userID!);

  /// Returns the power levels from all users for this room or null if not given.
  @Deprecated('Use `getPowerLevelByUserId(String userId)` instead')
  Map<String, int>? get powerLevels {
    final powerLevelState =
        getState(EventTypes.RoomPowerLevels)?.content['users'];
    return (powerLevelState is Map<String, int>) ? powerLevelState : null;
  }

  /// Uploads a new user avatar for this room. Returns the event ID of the new
  /// m.room.avatar event. Leave empty to remove the current avatar.
  Future<String> setAvatar(MatrixFile? file) async {
    final uploadResp = file == null
        ? null
        : await client.uploadContent(file.bytes, filename: file.name);
    return await client.setRoomStateWithKey(
      id,
      EventTypes.RoomAvatar,
      '',
      {
        if (uploadResp != null) 'url': uploadResp.toString(),
      },
    );
  }

  /// The level required to ban a user.
  bool get canBan =>
      (getState(EventTypes.RoomPowerLevels)?.content.tryGet<int>('ban') ??
          50) <=
      ownPowerLevel;

  /// returns if user can change a particular state event by comparing `ownPowerLevel`
  /// with possible overrides in `events`, if not present compares `ownPowerLevel`
  /// with state_default
  bool canChangeStateEvent(String action) {
    return powerForChangingStateEvent(action) <= ownPowerLevel;
  }

  /// returns the powerlevel required for chaning the `action` defaults to
  /// state_default if `action` isn't specified in events override.
  /// If there is no state_default in the m.room.power_levels event, the
  /// state_default is 50. If the room contains no m.room.power_levels event,
  /// the state_default is 0.
  int powerForChangingStateEvent(String action) {
    final powerLevelMap = getState(EventTypes.RoomPowerLevels)?.content;
    if (powerLevelMap == null) return 0;
    return powerLevelMap
            .tryGetMap<String, Object?>('events')
            ?.tryGet<int>(action) ??
        powerLevelMap.tryGet<int>('state_default') ??
        50;
  }

  bool get canCreateGroupCall =>
      canChangeStateEvent(EventTypes.GroupCallPrefix) && groupCallsEnabled;

  bool get canJoinGroupCall =>
      canChangeStateEvent(EventTypes.GroupCallMemberPrefix) &&
      groupCallsEnabled;

  /// if returned value is not null `org.matrix.msc3401.call.member` is present
  /// and group calls can be used
  bool get groupCallsEnabled {
    final powerLevelMap = getState(EventTypes.RoomPowerLevels)?.content;
    if (powerLevelMap == null) return false;
    return powerForChangingStateEvent(EventTypes.GroupCallMemberPrefix) <=
            getDefaultPowerLevel(powerLevelMap) &&
        powerForChangingStateEvent(EventTypes.GroupCallPrefix) <=
            getDefaultPowerLevel(powerLevelMap);
  }

  /// sets the `org.matrix.msc3401.call.member` power level to users default for
  /// group calls, needs permissions to change power levels
  Future<void> enableGroupCalls() async {
    if (!canChangePowerLevel) return;
    final currentPowerLevelsMap = getState(EventTypes.RoomPowerLevels)?.content;
    if (currentPowerLevelsMap != null) {
      final newPowerLevelMap = currentPowerLevelsMap;
      final eventsMap = newPowerLevelMap.tryGetMap<String, Object?>('events') ??
          <String, Object?>{};
      eventsMap.addAll({
        EventTypes.GroupCallPrefix: getDefaultPowerLevel(currentPowerLevelsMap),
        EventTypes.GroupCallMemberPrefix:
            getDefaultPowerLevel(currentPowerLevelsMap)
      });
      newPowerLevelMap.addAll({'events': eventsMap});
      await client.setRoomStateWithKey(
        id,
        EventTypes.RoomPowerLevels,
        '',
        newPowerLevelMap,
      );
    }
  }

  /// Takes in `[m.room.power_levels].content` and returns the default power level
  int getDefaultPowerLevel(Map<String, dynamic> powerLevelMap) {
    return powerLevelMap.tryGet('users_default') ?? 0;
  }

  /// The default level required to send message events. This checks if the
  /// user is capable of sending `m.room.message` events.
  /// Please be aware that this also returns false
  /// if the room is encrypted but the client is not able to use encryption.
  /// If you do not want this check or want to check other events like
  /// `m.sticker` use `canSendEvent('<event-type>')`.
  bool get canSendDefaultMessages {
    if (encrypted && !client.encryptionEnabled) return false;

    return canSendEvent(encrypted ? EventTypes.Encrypted : EventTypes.Message);
  }

  /// The level required to invite a user.
  bool get canInvite =>
      (getState(EventTypes.RoomPowerLevels)?.content.tryGet<int>('invite') ??
          0) <=
      ownPowerLevel;

  /// The level required to kick a user.
  bool get canKick =>
      (getState(EventTypes.RoomPowerLevels)?.content.tryGet<int>('kick') ??
          50) <=
      ownPowerLevel;

  /// The level required to redact an event.
  bool get canRedact =>
      (getState(EventTypes.RoomPowerLevels)?.content.tryGet<int>('redact') ??
          50) <=
      ownPowerLevel;

  ///  	The default level required to send state events. Can be overridden by the events key.
  bool get canSendDefaultStates {
    final powerLevelsMap = getState(EventTypes.RoomPowerLevels)?.content;
    if (powerLevelsMap == null) return 0 <= ownPowerLevel;
    return (getState(EventTypes.RoomPowerLevels)
                ?.content
                .tryGet<int>('state_default') ??
            50) <=
        ownPowerLevel;
  }

  bool get canChangePowerLevel =>
      canChangeStateEvent(EventTypes.RoomPowerLevels);

  /// The level required to send a certain event. Defaults to 0 if there is no
  /// events_default set or there is no power level state in the room.
  bool canSendEvent(String eventType) {
    final powerLevelsMap = getState(EventTypes.RoomPowerLevels)?.content;

    final pl = powerLevelsMap
            ?.tryGetMap<String, Object?>('events')
            ?.tryGet<int>(eventType) ??
        powerLevelsMap?.tryGet<int>('events_default') ??
        0;

    return ownPowerLevel >= pl;
  }

  /// The power level requirements for specific notification types.
  bool canSendNotification(String userid, {String notificationType = 'room'}) {
    final userLevel = getPowerLevelByUserId(userid);
    final notificationLevel = getState(EventTypes.RoomPowerLevels)
            ?.content
            .tryGetMap<String, Object?>('notifications')
            ?.tryGet<int>(notificationType) ??
        50;

    return userLevel >= notificationLevel;
  }

  /// Returns the [PushRuleState] for this room, based on the m.push_rules stored in
  /// the account_data.
  PushRuleState get pushRuleState {
    final globalPushRules =
        client.accountData['m.push_rules']?.content['global'];
    if (globalPushRules is! Map) {
      return PushRuleState.notify;
    }

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
    if (newState == pushRuleState) return;
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
  Future<String?> redactEvent(String eventId,
      {String? reason, String? txid}) async {
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
  Future<void> setTyping(bool isTyping, {int? timeout}) =>
      client.setTyping(client.userID!, id, isTyping, timeout: timeout);

  /// A room may be public meaning anyone can join the room without any prior action. Alternatively,
  /// it can be invite meaning that a user who wishes to join the room must first receive an invite
  /// to the room from someone already inside of the room. Currently, knock and private are reserved
  /// keywords which are not implemented.
  JoinRules? get joinRules {
    final joinRule = getState(EventTypes.RoomJoinRules)?.content['join_rule'];
    return joinRule != null
        ? JoinRules.values.firstWhereOrNull(
            (r) => r.toString().replaceAll('JoinRules.', '') == joinRule)
        : null;
  }

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
  bool get canChangeJoinRules => canChangeStateEvent(EventTypes.RoomJoinRules);

  /// This event controls whether guest users are allowed to join rooms. If this event
  /// is absent, servers should act as if it is present and has the guest_access value "forbidden".
  GuestAccess get guestAccess {
    final ga = getState(EventTypes.GuestAccess)?.content['guest_access'];
    return ga != null
        ? (_guestAccessMap.map((k, v) => MapEntry(v, k))[ga] ??
            GuestAccess.forbidden)
        : GuestAccess.forbidden;
  }

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
  bool get canChangeGuestAccess => canChangeStateEvent(EventTypes.GuestAccess);

  /// This event controls whether a user can see the events that happened in a room from before they joined.
  HistoryVisibility? get historyVisibility {
    final hv =
        getState(EventTypes.HistoryVisibility)?.content['history_visibility'];
    return hv != null
        ? _historyVisibilityMap.map((k, v) => MapEntry(v, k))[hv]
        : null;
  }

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
      canChangeStateEvent(EventTypes.HistoryVisibility);

  /// Returns the encryption algorithm. Currently only `m.megolm.v1.aes-sha2` is supported.
  /// Returns null if there is no encryption algorithm.
  String? get encryptionAlgorithm =>
      getState(EventTypes.Encryption)?.parsedRoomEncryptionContent.algorithm;

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
    await client.userDeviceKeysLoading;
    final deviceKeys = <DeviceKeys>[];
    final users = await requestParticipants();
    for (final user in users) {
      final userDeviceKeys = client.userDeviceKeys[user.id]?.deviceKeys.values;
      if ([Membership.invite, Membership.join].contains(user.membership) &&
          userDeviceKeys != null) {
        for (final deviceKeyEntry in userDeviceKeys) {
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
    await client.encryption?.keyManager.request(this, sessionId, senderKey);
  }

  Future<void> _handleFakeSync(SyncUpdate syncUpdate,
      {Direction? direction}) async {
    if (client.database != null) {
      await client.database?.transaction(() async {
        await client.handleSync(syncUpdate, direction: direction);
      });
    } else {
      await client.handleSync(syncUpdate, direction: direction);
    }
  }

  /// Whether this is an extinct room which has been archived in favor of a new
  /// room which replaces this. Use `getLegacyRoomInformations()` to get more
  /// informations about it if this is true.
  bool get isExtinct => getState(EventTypes.RoomTombstone) != null;

  /// Returns informations about how this room is
  TombstoneContent? get extinctInformations =>
      getState(EventTypes.RoomTombstone)?.parsedTombstoneContent;

  /// Checks if the `m.room.create` state has a `type` key with the value
  /// `m.space`.
  bool get isSpace =>
      getState(EventTypes.RoomCreate)?.content.tryGet<String>('type') ==
      RoomCreationTypes.mSpace; // TODO: Magic string!

  /// The parents of this room. Currently this SDK doesn't yet set the canonical
  /// flag and is not checking if this room is in fact a child of this space.
  /// You should therefore not rely on this and always check the children of
  /// the space.
  List<SpaceParent> get spaceParents =>
      states[EventTypes.spaceParent]
          ?.values
          .map((state) => SpaceParent.fromState(state))
          .where((child) => child.via?.isNotEmpty ?? false)
          .toList() ??
      [];

  /// List all children of this space. Children without a `via` domain will be
  /// ignored.
  /// Children are sorted by the `order` while those without this field will be
  /// sorted at the end of the list.
  List<SpaceChild> get spaceChildren => !isSpace
      ? throw Exception('Room is not a space!')
      : (states[EventTypes.spaceChild]
              ?.values
              .map((state) => SpaceChild.fromState(state))
              .where((child) => child.via?.isNotEmpty ?? false)
              .toList() ??
          [])
    ..sort((a, b) => a.order.isEmpty || b.order.isEmpty
        ? b.order.compareTo(a.order)
        : a.order.compareTo(b.order));

  /// Adds or edits a child of this space.
  Future<void> setSpaceChild(
    String roomId, {
    List<String>? via,
    String? order,
    bool? suggested,
  }) async {
    if (!isSpace) throw Exception('Room is not a space!');
    via ??= [client.userID!.domain!];
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

  /// Generates a matrix.to link with appropriate routing info to share the room
  Future<Uri> matrixToInviteLink() async {
    if (canonicalAlias.isNotEmpty) {
      return Uri.parse(
          'https://matrix.to/#/${Uri.encodeComponent(canonicalAlias)}');
    }
    final List queryParameters = [];
    final users = await requestParticipants();
    final currentPowerLevelsMap = getState(EventTypes.RoomPowerLevels)?.content;

    final temp = List<User>.from(users);
    temp.removeWhere((user) => user.powerLevel < 50);
    if (currentPowerLevelsMap != null) {
      // just for weird rooms
      temp.removeWhere((user) =>
          user.powerLevel < getDefaultPowerLevel(currentPowerLevelsMap));
    }

    if (temp.isNotEmpty) {
      temp.sort((a, b) => a.powerLevel.compareTo(b.powerLevel));
      if (temp.last.id.domain != null) {
        queryParameters.add(temp.last.id.domain!);
      }
    }

    final Map<String, int> servers = {};
    for (final user in users) {
      if (user.id.domain != null) {
        if (servers.containsKey(user.id.domain!)) {
          servers[user.id.domain!] = servers[user.id.domain!]! + 1;
        } else {
          servers[user.id.domain!] = 1;
        }
      }
    }
    final sortedServers = Map.fromEntries(servers.entries.toList()
      ..sort((e1, e2) => e1.value.compareTo(e2.value)));
    for (var i = 0; i <= 2; i++) {
      if (!queryParameters.contains(sortedServers.keys.last)) {
        queryParameters.add(sortedServers.keys.last);
      }
      sortedServers.remove(sortedServers.keys.last);
    }

    var queryString = '?';
    for (var i = 0;
        i <= (queryParameters.length > 2 ? 2 : queryParameters.length);
        i++) {
      if (i != 0) {
        queryString += '&';
      }
      queryString += 'via=${queryParameters[i]}';
    }
    return Uri.parse(
        'https://matrix.to/#/${Uri.encodeComponent(id)}$queryString');
  }

  /// Remove a child from this space by setting the `via` to an empty list.
  Future<void> removeSpaceChild(String roomId) => !isSpace
      ? throw Exception('Room is not a space!')
      : setSpaceChild(roomId, via: const []);

  @override
  bool operator ==(dynamic other) => (other is Room && other.id == id);

  @override
  int get hashCode => Object.hashAll([id]);
}

enum EncryptionHealthState {
  allVerified,
  unverifiedDevices,
}
