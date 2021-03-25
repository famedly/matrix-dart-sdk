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

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../famedlysdk.dart';
import 'database/database.dart' show DbRoomState, DbEvent;
import 'room.dart';
import 'utils/matrix_localizations.dart';
import 'utils/receipt.dart';
import 'utils/run_in_background.dart';
import 'utils/event_localizations.dart';
import 'utils/crypto/encrypted_file.dart';

abstract class RelationshipTypes {
  static const String reply = 'm.in_reply_to';
  static const String edit = 'm.replace';
  static const String reaction = 'm.annotation';
}

/// All data exchanged over Matrix is expressed as an "event". Typically each client action (e.g. sending a message) correlates with exactly one event.
class Event extends MatrixEvent {
  User get sender => room.getUserByMXIDSync(senderId ?? '@unknown');

  @Deprecated('Use [originServerTs] instead')
  DateTime get time => originServerTs;

  @Deprecated('Use [type] instead')
  String get typeKey => type;

  @Deprecated('Use [sender.calcDisplayname()] instead')
  String get senderName => sender.calcDisplayname();

  /// The room this event belongs to. May be null.
  final Room room;

  /// The status of this event.
  /// -1=ERROR
  ///  0=SENDING
  ///  1=SENT
  ///  2=TIMELINE
  ///  3=ROOM_STATE
  int status;

  static const int defaultStatus = 2;
  static const Map<String, int> statusType = {
    'error': -1,
    'sending': 0,
    'sent': 1,
    'timeline': 2,
    'roomState': 3,
  };

  /// Optional. The event that redacted this event, if any. Otherwise null.
  Event get redactedBecause =>
      unsigned != null && unsigned['redacted_because'] is Map
          ? Event.fromJson(unsigned['redacted_because'], room)
          : null;

  bool get redacted => redactedBecause != null;

  User get stateKeyUser => room.getUserByMXIDSync(stateKey);

  double sortOrder;

  Event(
      {this.status = defaultStatus,
      Map<String, dynamic> content,
      String type,
      String eventId,
      String roomId,
      String senderId,
      DateTime originServerTs,
      Map<String, dynamic> unsigned,
      Map<String, dynamic> prevContent,
      String stateKey,
      this.room,
      this.sortOrder = 0.0}) {
    this.content = content;
    this.type = type;
    this.eventId = eventId;
    this.roomId = roomId ?? room?.id;
    this.senderId = senderId;
    this.unsigned = unsigned;
    // synapse unfortunatley isn't following the spec and tosses the prev_content
    // into the unsigned block.
    // Currently we are facing a very strange bug in web which is impossible to debug.
    // It may be because of this line so we put this in try-catch until we can fix it.
    try {
      this.prevContent = (prevContent != null && prevContent.isNotEmpty)
          ? prevContent
          : (unsigned != null &&
                  unsigned.containsKey('prev_content') &&
                  unsigned['prev_content'] is Map)
              ? unsigned['prev_content']
              : null;
    } catch (_) {
      // A strange bug in dart web makes this crash
    }
    this.stateKey = stateKey;
    this.originServerTs = originServerTs;
  }

  static Map<String, dynamic> getMapFromPayload(dynamic payload) {
    if (payload is String) {
      try {
        return json.decode(payload);
      } catch (e) {
        return {};
      }
    }
    if (payload is Map<String, dynamic>) return payload;
    return {};
  }

  factory Event.fromMatrixEvent(
    MatrixEvent matrixEvent,
    Room room, {
    double sortOrder,
    int status,
  }) =>
      Event(
        status: status,
        content: matrixEvent.content,
        type: matrixEvent.type,
        eventId: matrixEvent.eventId,
        roomId: room.id,
        senderId: matrixEvent.senderId,
        originServerTs: matrixEvent.originServerTs,
        unsigned: matrixEvent.unsigned,
        prevContent: matrixEvent.prevContent,
        stateKey: matrixEvent.stateKey,
        room: room,
        sortOrder: sortOrder,
      );

  /// Get a State event from a table row or from the event stream.
  factory Event.fromJson(Map<String, dynamic> jsonPayload, Room room,
      [double sortOrder]) {
    final content = Event.getMapFromPayload(jsonPayload['content']);
    final unsigned = Event.getMapFromPayload(jsonPayload['unsigned']);
    final prevContent = Event.getMapFromPayload(jsonPayload['prev_content']);
    return Event(
      status: jsonPayload['status'] ??
          unsigned[messageSendingStatusKey] ??
          defaultStatus,
      stateKey: jsonPayload['state_key'],
      prevContent: prevContent,
      content: content,
      type: jsonPayload['type'],
      eventId: jsonPayload['event_id'],
      roomId: jsonPayload['room_id'],
      senderId: jsonPayload['sender'],
      originServerTs: jsonPayload.containsKey('origin_server_ts')
          ? DateTime.fromMillisecondsSinceEpoch(jsonPayload['origin_server_ts'])
          : DateTime.now(),
      unsigned: unsigned,
      room: room,
      sortOrder: sortOrder ?? 0.0,
    );
  }

  /// Get an event from either DbRoomState or DbEvent
  factory Event.fromDb(dynamic dbEntry, Room room) {
    if (!(dbEntry is DbRoomState || dbEntry is DbEvent)) {
      throw ('Unknown db type');
    }
    final content = Event.getMapFromPayload(dbEntry.content);
    final unsigned = Event.getMapFromPayload(dbEntry.unsigned);
    final prevContent = Event.getMapFromPayload(dbEntry.prevContent);
    return Event(
      status: (dbEntry is DbEvent ? dbEntry.status : null) ?? defaultStatus,
      stateKey: dbEntry.stateKey,
      prevContent: prevContent,
      content: content,
      type: dbEntry.type,
      eventId: dbEntry.eventId,
      roomId: dbEntry.roomId,
      senderId: dbEntry.sender,
      originServerTs: dbEntry.originServerTs != null
          ? DateTime.fromMillisecondsSinceEpoch(dbEntry.originServerTs)
          : DateTime.now(),
      unsigned: unsigned,
      room: room,
      sortOrder: dbEntry.sortOrder ?? 0.0,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (stateKey != null) data['state_key'] = stateKey;
    if (prevContent != null && prevContent.isNotEmpty) {
      data['prev_content'] = prevContent;
    }
    data['content'] = content;
    data['type'] = type;
    data['event_id'] = eventId;
    data['room_id'] = roomId;
    data['sender'] = senderId;
    data['origin_server_ts'] = originServerTs.millisecondsSinceEpoch;
    if (unsigned != null && unsigned.isNotEmpty) {
      data['unsigned'] = unsigned;
    }
    return data;
  }

  User get asUser => User.fromState(
      stateKey: stateKey,
      prevContent: prevContent,
      content: content,
      typeKey: type,
      eventId: eventId,
      roomId: roomId,
      senderId: senderId,
      originServerTs: originServerTs,
      unsigned: unsigned,
      room: room);

  String get messageType => type == EventTypes.Sticker
      ? MessageTypes.Sticker
      : (content['msgtype'] is String ? content['msgtype'] : MessageTypes.Text);

  void setRedactionEvent(Event redactedBecause) {
    unsigned = {
      'redacted_because': redactedBecause.toJson(),
    };
    prevContent = null;
    var contentKeyWhiteList = <String>[];
    switch (type) {
      case EventTypes.RoomMember:
        contentKeyWhiteList.add('membership');
        break;
      case EventTypes.RoomCreate:
        contentKeyWhiteList.add('creator');
        break;
      case EventTypes.RoomJoinRules:
        contentKeyWhiteList.add('join_rule');
        break;
      case EventTypes.RoomPowerLevels:
        contentKeyWhiteList.add('ban');
        contentKeyWhiteList.add('events');
        contentKeyWhiteList.add('events_default');
        contentKeyWhiteList.add('kick');
        contentKeyWhiteList.add('redact');
        contentKeyWhiteList.add('state_default');
        contentKeyWhiteList.add('users');
        contentKeyWhiteList.add('users_default');
        break;
      case EventTypes.RoomAliases:
        contentKeyWhiteList.add('aliases');
        break;
      case EventTypes.HistoryVisibility:
        contentKeyWhiteList.add('history_visibility');
        break;
      default:
        break;
    }
    content.removeWhere((k, v) => !contentKeyWhiteList.contains(k));
  }

  /// Returns the body of this event if it has a body.
  String get text => content['body'] is String ? content['body'] : '';

  /// Returns the formatted boy of this event if it has a formatted body.
  String get formattedText =>
      content['formatted_body'] is String ? content['formatted_body'] : '';

  /// Use this to get the body.
  String get body {
    if (redacted) return 'Redacted';
    if (text != '') return text;
    if (formattedText != '') return formattedText;
    return '$type';
  }

  /// Returns a list of [Receipt] instances for this event.
  List<Receipt> get receipts {
    if (!(room.roomAccountData.containsKey('m.receipt'))) return [];
    var receiptsList = <Receipt>[];
    for (var entry in room.roomAccountData['m.receipt'].content.entries) {
      if (entry.value['event_id'] == eventId) {
        receiptsList.add(Receipt(room.getUserByMXIDSync(entry.key),
            DateTime.fromMillisecondsSinceEpoch(entry.value['ts'])));
      }
    }
    return receiptsList;
  }

  /// Removes this event if the status is < 1. This event will just be removed
  /// from the database and the timelines. Returns false if not removed.
  Future<bool> remove() async {
    if (status < 1) {
      await room.client.database?.removeEvent(room.client.id, eventId, room.id);

      room.client.onEvent.add(EventUpdate(
          roomID: room.id,
          type: EventUpdateType.timeline,
          content: {
            'event_id': eventId,
            'status': -2,
            'content': {'body': 'Removed...'}
          },
          sortOrder: sortOrder));
      return true;
    }
    return false;
  }

  /// Try to send this event again. Only works with events of status -1.
  Future<String> sendAgain({String txid}) async {
    if (status != -1) return null;
    // we do not remove the event here. It will automatically be updated
    // in the `sendEvent` method to transition -1 -> 0 -> 1 -> 2
    final newEventId = await room.sendEvent(
      content,
      txid: txid ?? unsigned['transaction_id'] ?? eventId,
    );
    return newEventId;
  }

  /// Whether the client is allowed to redact this event.
  bool get canRedact => senderId == room.client.userID || room.canRedact;

  /// Redacts this event. Throws `ErrorResponse` on error.
  Future<dynamic> redact({String reason, String txid}) =>
      room.redactEvent(eventId, reason: reason, txid: txid);

  /// Searches for the reply event in the given timeline.
  Future<Event> getReplyEvent(Timeline timeline) async {
    if (relationshipType != RelationshipTypes.reply) return null;
    return await timeline.getEventById(relationshipEventId);
  }

  /// If this event is encrypted and the decryption was not successful because
  /// the session is unknown, this requests the session key from other devices
  /// in the room. If the event is not encrypted or the decryption failed because
  /// of a different error, this throws an exception.
  Future<void> requestKey() async {
    if (type != EventTypes.Encrypted ||
        messageType != MessageTypes.BadEncrypted ||
        content['can_request_session'] != true) {
      throw ('Session key not requestable');
    }
    await room.requestSessionKey(content['session_id'], content['sender_key']);
    return;
  }

  /// Gets the info map of file events, or a blank map if none present
  Map get infoMap =>
      content['info'] is Map ? content['info'] : <String, dynamic>{};

  /// Gets the thumbnail info map of file events, or a blank map if nonepresent
  Map get thumbnailInfoMap => infoMap['thumbnail_info'] is Map
      ? infoMap['thumbnail_info']
      : <String, dynamic>{};

  /// Returns if a file event has an attachment
  bool get hasAttachment => content['url'] is String || content['file'] is Map;

  /// Returns if a file event has a thumbnail
  bool get hasThumbnail =>
      infoMap['thumbnail_url'] is String || infoMap['thumbnail_file'] is Map;

  /// Returns if a file events attachment is encrypted
  bool get isAttachmentEncrypted => content['file'] is Map;

  /// Returns if a file events thumbnail is encrypted
  bool get isThumbnailEncrypted => infoMap['thumbnail_file'] is Map;

  /// Gets the mimetipe of the attachment of a file event, or a blank string if not present
  String get attachmentMimetype => infoMap['mimetype'] is String
      ? infoMap['mimetype'].toLowerCase()
      : (content['file'] is Map && content['file']['mimetype'] is String
          ? content['file']['mimetype']
          : '');

  /// Gets the mimetype of the thumbnail of a file event, or a blank string if not present
  String get thumbnailMimetype => thumbnailInfoMap['mimetype'] is String
      ? thumbnailInfoMap['mimetype'].toLowerCase()
      : (infoMap['thumbnail_file'] is Map &&
              infoMap['thumbnail_file']['mimetype'] is String
          ? infoMap['thumbnail_file']['mimetype']
          : '');

  /// Gets the underyling mxc url of an attachment of a file event, or null if not present
  String get attachmentMxcUrl =>
      isAttachmentEncrypted ? content['file']['url'] : content['url'];

  /// Gets the underyling mxc url of a thumbnail of a file event, or null if not present
  String get thumbnailMxcUrl => isThumbnailEncrypted
      ? infoMap['thumbnail_file']['url']
      : infoMap['thumbnail_url'];

  /// Gets the mxc url of an attachemnt/thumbnail of a file event, taking sizes into account, or null if not present
  String attachmentOrThumbnailMxcUrl({bool getThumbnail = false}) {
    if (getThumbnail &&
        infoMap['size'] is int &&
        thumbnailInfoMap['size'] is int &&
        infoMap['size'] <= thumbnailInfoMap['size']) {
      getThumbnail = false;
    }
    if (getThumbnail && !hasThumbnail) {
      getThumbnail = false;
    }
    return getThumbnail ? thumbnailMxcUrl : attachmentMxcUrl;
  }

  // size determined from an approximate 800x800 jpeg thumbnail with method=scale
  static const _minNoThumbSize = 80 * 1024;

  /// Gets the attachment https URL to display in the timeline, taking into account if the original image is tiny.
  /// Returns null for encrypted rooms, if the image can't be fetched via http url or if the event does not contain an attachment.
  /// Set [getThumbnail] to true to fetch the thumbnail, set [width], [height] and [method]
  /// for the respective thumbnailing properties.
  /// [minNoThumbSize] is the minimum size that an original image may be to not fetch its thumbnail, defaults to 80k
  /// [useThumbnailMxcUrl] says weather to use the mxc url of the thumbnail, rather than the original attachment.
  ///  [animated] says weather the thumbnail is animated
  Uri getAttachmentUrl(
      {bool getThumbnail = false,
      bool useThumbnailMxcUrl = false,
      double width = 800.0,
      double height = 800.0,
      ThumbnailMethod method = ThumbnailMethod.scale,
      int minNoThumbSize = _minNoThumbSize,
      bool animated = false}) {
    if (![EventTypes.Message, EventTypes.Sticker].contains(type) ||
        !hasAttachment ||
        isAttachmentEncrypted) {
      return null; // can't url-thumbnail in encrypted rooms
    }
    if (useThumbnailMxcUrl && !hasThumbnail) {
      return null; // can't fetch from thumbnail
    }
    final thisInfoMap = useThumbnailMxcUrl ? thumbnailInfoMap : infoMap;
    final thisMxcUrl =
        useThumbnailMxcUrl ? infoMap['thumbnail_url'] : content['url'];
    // if we have as method scale, we can return safely the original image, should it be small enough
    if (getThumbnail &&
        method == ThumbnailMethod.scale &&
        thisInfoMap['size'] is int &&
        thisInfoMap['size'] < minNoThumbSize) {
      getThumbnail = false;
    }
    // now generate the actual URLs
    if (getThumbnail) {
      return Uri.parse(thisMxcUrl).getThumbnail(
        room.client,
        width: width,
        height: height,
        method: method,
        animated: animated,
      );
    } else {
      return Uri.parse(thisMxcUrl).getDownloadLink(room.client);
    }
  }

  /// Returns if an attachment is in the local store
  Future<bool> isAttachmentInLocalStore({bool getThumbnail = false}) async {
    if (![EventTypes.Message, EventTypes.Sticker].contains(type)) {
      throw ("This event has the type '$type' and so it can't contain an attachment.");
    }
    final mxcUrl = attachmentOrThumbnailMxcUrl(getThumbnail: getThumbnail);
    if (!(mxcUrl is String)) {
      throw ("This event hasn't any attachment or thumbnail.");
    }
    getThumbnail = mxcUrl != attachmentMxcUrl;
    // Is this file storeable?
    final thisInfoMap = getThumbnail ? thumbnailInfoMap : infoMap;
    var storeable = room.client.database != null &&
        thisInfoMap['size'] is int &&
        thisInfoMap['size'] <= room.client.database.maxFileSize;

    Uint8List uint8list;
    if (storeable) {
      uint8list = await room.client.database.getFile(mxcUrl);
    }
    return uint8list != null;
  }

  /// Downloads (and decryptes if necessary) the attachment of this
  /// event and returns it as a [MatrixFile]. If this event doesn't
  /// contain an attachment, this throws an error. Set [getThumbnail] to
  /// true to download the thumbnail instead.
  Future<MatrixFile> downloadAndDecryptAttachment(
      {bool getThumbnail = false,
      Future<Uint8List> Function(Uri) downloadCallback}) async {
    if (![EventTypes.Message, EventTypes.Sticker].contains(type)) {
      throw ("This event has the type '$type' and so it can't contain an attachment.");
    }
    final mxcUrl = attachmentOrThumbnailMxcUrl(getThumbnail: getThumbnail);
    if (!(mxcUrl is String)) {
      throw ("This event hasn't any attachment or thumbnail.");
    }
    getThumbnail = mxcUrl != attachmentMxcUrl;
    final isEncrypted =
        getThumbnail ? isThumbnailEncrypted : isAttachmentEncrypted;

    if (isEncrypted && !room.client.encryptionEnabled) {
      throw ('Encryption is not enabled in your Client.');
    }
    final mxContent = Uri.parse(mxcUrl);

    Uint8List uint8list;

    // Is this file storeable?
    final thisInfoMap = getThumbnail ? thumbnailInfoMap : infoMap;
    var storeable = room.client.database != null &&
        thisInfoMap['size'] is int &&
        thisInfoMap['size'] <= room.client.database.maxFileSize;

    if (storeable) {
      uint8list = await room.client.database.getFile(mxContent.toString());
    }

    // Download the file
    if (uint8list == null) {
      downloadCallback ??= (Uri url) async {
        return (await http.get(url)).bodyBytes;
      };
      uint8list =
          await downloadCallback(mxContent.getDownloadLink(room.client));
      storeable = storeable &&
          uint8list.lengthInBytes < room.client.database.maxFileSize;
      if (storeable) {
        await room.client.database.storeFile(mxContent.toString(), uint8list,
            DateTime.now().millisecondsSinceEpoch);
      }
    }

    // Decrypt the file
    if (isEncrypted) {
      final fileMap =
          getThumbnail ? infoMap['thumbnail_file'] : content['file'];
      if (!fileMap['key']['key_ops'].contains('decrypt')) {
        throw ("Missing 'decrypt' in 'key_ops'.");
      }
      final encryptedFile = EncryptedFile(
        data: uint8list,
        iv: fileMap['iv'],
        k: fileMap['key']['k'],
        sha256: fileMap['hashes']['sha256'],
      );
      uint8list = await runInBackground(decryptFile, encryptedFile);
    }
    return MatrixFile(bytes: uint8list, name: body);
  }

  /// Returns if this is a known event type.
  bool get isEventTypeKnown =>
      EventLocalizations.localizationsMap.containsKey(type);

  /// Returns a localized String representation of this event. For a
  /// room list you may find [withSenderNamePrefix] useful. Set [hideReply] to
  /// crop all lines starting with '>'.
  String getLocalizedBody(MatrixLocalizations i18n,
      {bool withSenderNamePrefix = false, bool hideReply = false}) {
    if (redacted) {
      return i18n.removedBy(redactedBecause.sender.calcDisplayname());
    }
    final callback = EventLocalizations.localizationsMap[type];
    var localizedBody = i18n.unknownEvent(type);
    if (callback != null) {
      localizedBody = callback(this, i18n);
    }

    // Hide reply fallback
    if (hideReply) {
      localizedBody = localizedBody.replaceFirst(
          RegExp(r'^>( \*)? <[^>]+>[^\n\r]+\r?\n(> [^\n]*\r?\n)*\r?\n'), '');
    }

    // Add the sender name prefix
    if (withSenderNamePrefix &&
        type == EventTypes.Message &&
        textOnlyMessageTypes.contains(messageType)) {
      final senderNameOrYou =
          senderId == room.client.userID ? i18n.you : sender.calcDisplayname();
      localizedBody = '$senderNameOrYou: $localizedBody';
    }

    return localizedBody;
  }

  static const Set<String> textOnlyMessageTypes = {
    MessageTypes.Text,
    MessageTypes.Notice,
    MessageTypes.Emote,
    MessageTypes.None,
  };

  /// returns if this event matches the passed event or transaction id
  bool matchesEventOrTransactionId(String search) {
    if (search == null) {
      return false;
    }
    if (eventId == search) {
      return true;
    }
    return unsigned != null && unsigned['transaction_id'] == search;
  }

  /// Get the relationship type of an event. `null` if there is none
  String get relationshipType {
    if (content?.tryGet<Map<String, dynamic>>('m.relates_to') == null) {
      return null;
    }
    if (content['m.relates_to'].containsKey('m.in_reply_to')) {
      return RelationshipTypes.reply;
    }
    return content
        .tryGet<Map<String, dynamic>>('m.relates_to')
        .tryGet<String>('rel_type');
  }

  /// Get the event ID that this relationship will reference. `null` if there is none
  String get relationshipEventId {
    if (content == null || !(content['m.relates_to'] is Map)) {
      return null;
    }
    if (content['m.relates_to'].containsKey('event_id')) {
      return content['m.relates_to']['event_id'];
    }
    if (content['m.relates_to']['m.in_reply_to'] is Map &&
        content['m.relates_to']['m.in_reply_to'].containsKey('event_id')) {
      return content['m.relates_to']['m.in_reply_to']['event_id'];
    }
    return null;
  }

  /// Get wether this event has aggregated events from a certain [type]
  /// To be able to do that you need to pass a [timeline]
  bool hasAggregatedEvents(Timeline timeline, String type) =>
      timeline.aggregatedEvents.containsKey(eventId) &&
      timeline.aggregatedEvents[eventId].containsKey(type);

  /// Get all the aggregated event objects for a given [type]. To be able to do this
  /// you have to pass a [timeline]
  Set<Event> aggregatedEvents(Timeline timeline, String type) =>
      hasAggregatedEvents(timeline, type)
          ? timeline.aggregatedEvents[eventId][type]
          : <Event>{};

  /// Fetches the event to be rendered, taking into account all the edits and the like.
  /// It needs a [timeline] for that.
  Event getDisplayEvent(Timeline timeline) {
    if (redacted) {
      return this;
    }
    if (hasAggregatedEvents(timeline, RelationshipTypes.edit)) {
      // alright, we have an edit
      final allEditEvents = aggregatedEvents(timeline, RelationshipTypes.edit)
          // we only allow edits made by the original author themself
          .where((e) => e.senderId == senderId && e.type == EventTypes.Message)
          .toList();
      // we need to check again if it isn't empty, as we potentially removed all
      // aggregated edits
      if (allEditEvents.isNotEmpty) {
        allEditEvents.sort((a, b) => a.sortOrder - b.sortOrder > 0 ? 1 : -1);
        var rawEvent = allEditEvents.last.toJson();
        // update the content of the new event to render
        if (rawEvent['content']['m.new_content'] is Map) {
          rawEvent['content'] = rawEvent['content']['m.new_content'];
        }
        return Event.fromJson(rawEvent, room);
      }
    }
    return this;
  }

  /// returns if a message is a rich message
  bool get isRichMessage =>
      content['format'] == 'org.matrix.custom.html' &&
      content['formatted_body'] is String;

  // regexes to fetch the number of emotes, including emoji, and if the message consists of only those
  // to match an emoji we can use the following regex:
  // (?:\x{00a9}|\x{00ae}|[\x{2000}-\x{3300}]|\x{d83c}[\x{d000}-\x{dfff}]|\x{d83d}[\x{d000}-\x{dfff}]|\x{d83e}[\x{d000}-\x{dfff}])[\x{fe00}-\x{fe0f}]?
  // we need to replace \x{0000} with \u0000, the comment is left in the other format to be able to paste into regex101.com
  // to see if there is a custom emote, we use the following regex: <img[^>]+data-mx-(?:emote|emoticon)(?==|>|\s)[^>]*>
  // now we combind the two to have four regexes:
  // 1. are there only emoji, or whitespace
  // 2. are there only emoji, emotes, or whitespace
  // 3. count number of emoji
  // 4- count number of emoji or emotes
  static final RegExp _onlyEmojiRegex = RegExp(
      r'^((?:\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])[\ufe00-\ufe0f]?|\s)*$',
      caseSensitive: false,
      multiLine: false);
  static final RegExp _onlyEmojiEmoteRegex = RegExp(
      r'^((?:\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])[\ufe00-\ufe0f]?|<img[^>]+data-mx-(?:emote|emoticon)(?==|>|\s)[^>]*>|\s)*$',
      caseSensitive: false,
      multiLine: false);
  static final RegExp _countEmojiRegex = RegExp(
      r'((?:\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])[\ufe00-\ufe0f]?)',
      caseSensitive: false,
      multiLine: false);
  static final RegExp _countEmojiEmoteRegex = RegExp(
      r'((?:\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])[\ufe00-\ufe0f]?|<img[^>]+data-mx-(?:emote|emoticon)(?==|>|\s)[^>]*>)',
      caseSensitive: false,
      multiLine: false);

  /// Returns if a given event only has emotes, emojis or whitespace as content.
  /// This is useful to determine if stand-alone emotes should be displayed bigger.
  bool get onlyEmotes => isRichMessage
      ? _onlyEmojiEmoteRegex.hasMatch(formattedText)
      : _onlyEmojiRegex.hasMatch(text);

  /// Gets the number of emotes in a given message. This is useful to determine if
  /// emotes should be displayed bigger. WARNING: This does **not** test if there are
  /// only emotes. Use `event.onlyEmotes` for that!
  int get numberEmotes => isRichMessage
      ? _countEmojiEmoteRegex.allMatches(formattedText).length
      : _countEmojiRegex.allMatches(text).length;
}
