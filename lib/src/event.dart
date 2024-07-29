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

import 'package:collection/collection.dart';
import 'package:html/parser.dart';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/event_localizations.dart';
import 'package:matrix/src/utils/file_send_request_credentials.dart';
import 'package:matrix/src/utils/html_to_text.dart';
import 'package:matrix/src/utils/markdown.dart';

abstract class RelationshipTypes {
  static const String reply = 'm.in_reply_to';
  static const String edit = 'm.replace';
  static const String reaction = 'm.annotation';
  static const String thread = 'm.thread';
}

/// All data exchanged over Matrix is expressed as an "event". Typically each client action (e.g. sending a message) correlates with exactly one event.
class Event extends MatrixEvent {
  /// Requests the user object of the sender of this event.
  Future<User?> fetchSenderUser() => room.requestUser(
        senderId,
        ignoreErrors: true,
      );

  @Deprecated(
      'Use eventSender instead or senderFromMemoryOrFallback for a synchronous alternative')
  User get sender => senderFromMemoryOrFallback;

  User get senderFromMemoryOrFallback =>
      room.unsafeGetUserFromMemoryOrFallback(senderId);

  /// The room this event belongs to. May be null.
  final Room room;

  /// The status of this event.
  EventStatus status;

  static const EventStatus defaultStatus = EventStatus.synced;

  /// Optional. The event that redacted this event, if any. Otherwise null.
  Event? get redactedBecause {
    final redacted_because = unsigned?['redacted_because'];
    final room = this.room;
    return (redacted_because is Map<String, dynamic>)
        ? Event.fromJson(redacted_because, room)
        : null;
  }

  bool get redacted => redactedBecause != null;

  User? get stateKeyUser => stateKey != null
      ? room.unsafeGetUserFromMemoryOrFallback(stateKey!)
      : null;

  MatrixEvent? _originalSource;

  MatrixEvent? get originalSource => _originalSource;

  Event({
    this.status = defaultStatus,
    required Map<String, dynamic> super.content,
    required super.type,
    required String eventId,
    required super.senderId,
    required DateTime originServerTs,
    Map<String, dynamic>? unsigned,
    Map<String, dynamic>? prevContent,
    String? stateKey,
    required this.room,
    MatrixEvent? originalSource,
  })  : _originalSource = originalSource,
        super(
          eventId: eventId,
          originServerTs: originServerTs,
          roomId: room.id,
        ) {
    this.eventId = eventId;
    this.unsigned = unsigned;
    // synapse unfortunately isn't following the spec and tosses the prev_content
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

    // Mark event as failed to send if status is `sending` and event is older
    // than the timeout. This should not happen with the deprecated Moor
    // database!
    if (status.isSending && room.client.database != null) {
      // Age of this event in milliseconds
      final age = DateTime.now().millisecondsSinceEpoch -
          originServerTs.millisecondsSinceEpoch;

      final room = this.room;
      if (age > room.client.sendTimelineEventTimeout.inMilliseconds) {
        // Update this event in database and open timelines
        final json = toJson();
        json['unsigned'] ??= <String, dynamic>{};
        json['unsigned'][messageSendingStatusKey] = EventStatus.error.intValue;
        // ignore: discarded_futures
        room.client.handleSync(
          SyncUpdate(
            nextBatch: '',
            rooms: RoomsUpdate(
              join: {
                room.id: JoinedRoomUpdate(
                  timeline: TimelineUpdate(
                    events: [MatrixEvent.fromJson(json)],
                  ),
                )
              },
            ),
          ),
        );
      }
    }
  }

  static Map<String, dynamic> getMapFromPayload(Object? payload) {
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
    EventStatus status = defaultStatus,
  }) =>
      Event(
        status: status,
        content: matrixEvent.content,
        type: matrixEvent.type,
        eventId: matrixEvent.eventId,
        senderId: matrixEvent.senderId,
        originServerTs: matrixEvent.originServerTs,
        unsigned: matrixEvent.unsigned,
        prevContent: matrixEvent.prevContent,
        stateKey: matrixEvent.stateKey,
        room: room,
      );

  /// Get a State event from a table row or from the event stream.
  factory Event.fromJson(
    Map<String, dynamic> jsonPayload,
    Room room,
  ) {
    final content = Event.getMapFromPayload(jsonPayload['content']);
    final unsigned = Event.getMapFromPayload(jsonPayload['unsigned']);
    final prevContent = Event.getMapFromPayload(jsonPayload['prev_content']);
    final originalSource =
        Event.getMapFromPayload(jsonPayload['original_source']);
    return Event(
        status: eventStatusFromInt(jsonPayload['status'] ??
            unsigned[messageSendingStatusKey] ??
            defaultStatus.intValue),
        stateKey: jsonPayload['state_key'],
        prevContent: prevContent,
        content: content,
        type: jsonPayload['type'],
        eventId: jsonPayload['event_id'] ?? '',
        senderId: jsonPayload['sender'],
        originServerTs: DateTime.fromMillisecondsSinceEpoch(
            jsonPayload['origin_server_ts'] ?? 0),
        unsigned: unsigned,
        room: room,
        originalSource: originalSource.isEmpty
            ? null
            : MatrixEvent.fromJson(originalSource));
  }

  @override
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (stateKey != null) data['state_key'] = stateKey;
    if (prevContent?.isNotEmpty == true) {
      data['prev_content'] = prevContent;
    }
    data['content'] = content;
    data['type'] = type;
    data['event_id'] = eventId;
    data['room_id'] = roomId;
    data['sender'] = senderId;
    data['origin_server_ts'] = originServerTs.millisecondsSinceEpoch;
    if (unsigned?.isNotEmpty == true) {
      data['unsigned'] = unsigned;
    }
    if (originalSource != null) {
      data['original_source'] = originalSource?.toJson();
    }
    return data;
  }

  User get asUser => User.fromState(
        // state key should always be set for member events
        stateKey: stateKey!,
        prevContent: prevContent,
        content: content,
        typeKey: type,
        senderId: senderId,
        room: room,
      );

  String get messageType => type == EventTypes.Sticker
      ? MessageTypes.Sticker
      : (content.tryGet<String>('msgtype') ?? MessageTypes.Text);

  void setRedactionEvent(Event redactedBecause) {
    unsigned = {
      'redacted_because': redactedBecause.toJson(),
    };
    prevContent = null;
    _originalSource = null;
    final contentKeyWhiteList = <String>[];
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
  String get text => content.tryGet<String>('body') ?? '';

  /// Returns the formatted boy of this event if it has a formatted body.
  String get formattedText => content.tryGet<String>('formatted_body') ?? '';

  /// Use this to get the body.
  String get body {
    if (redacted) return 'Redacted';
    if (text != '') return text;
    if (formattedText != '') return formattedText;
    return type;
  }

  /// Use this to get a plain-text representation of the event, stripping things
  /// like spoilers and thelike. Useful for plain text notifications.
  String get plaintextBody => content['format'] == 'org.matrix.custom.html'
      ? HtmlToText.convert(formattedText)
      : body;

  /// Returns a list of [Receipt] instances for this event.
  List<Receipt> get receipts {
    final room = this.room;
    final receipts = room.receiptState;
    final receiptsList = receipts.global.otherUsers.entries
        .where((entry) => entry.value.eventId == eventId)
        .map((entry) => Receipt(
            room.unsafeGetUserFromMemoryOrFallback(entry.key),
            entry.value.timestamp))
        .toList();

    // add your own only once
    final own = receipts.global.latestOwnReceipt ??
        receipts.mainThread?.latestOwnReceipt;
    if (own != null && own.eventId == eventId) {
      receiptsList.add(
        Receipt(room.unsafeGetUserFromMemoryOrFallback(room.client.userID!),
            own.timestamp),
      );
    }

    // also add main thread. https://github.com/famedly/product-management/issues/1020
    // also deduplicate.
    receiptsList.addAll(receipts.mainThread?.otherUsers.entries
            .where((entry) =>
                entry.value.eventId == eventId &&
                receiptsList.every((element) => element.user.id != entry.key))
            .map((entry) => Receipt(
                room.unsafeGetUserFromMemoryOrFallback(entry.key),
                entry.value.timestamp)) ??
        []);

    return receiptsList;
  }

  @Deprecated('Use [cancelSend()] instead.')
  Future<bool> remove() async {
    try {
      await cancelSend();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Removes an unsent or yet-to-send event from the database and timeline.
  /// These are events marked with the status `SENDING` or `ERROR`.
  /// Throws an exception if used for an already sent event!
  Future<void> cancelSend() async {
    if (status.isSent) {
      throw Exception('Can only delete events which are not sent yet!');
    }

    await room.client.database?.removeEvent(eventId, room.id);
    room.client.onCancelSendEvent.add(eventId);
  }

  /// Try to send this event again. Only works with events of status -1.
  Future<String?> sendAgain({String? txid}) async {
    if (!status.isError) return null;

    // Retry sending a file:
    if ({
      MessageTypes.Image,
      MessageTypes.Video,
      MessageTypes.Audio,
      MessageTypes.File,
    }.contains(messageType)) {
      final file = room.sendingFilePlaceholders[eventId];
      if (file == null) {
        await cancelSend();
        throw Exception('Can not try to send again. File is no longer cached.');
      }
      final thumbnail = room.sendingFileThumbnails[eventId];
      final credentials = FileSendRequestCredentials.fromJson(unsigned ?? {});
      final inReplyTo = credentials.inReplyTo == null
          ? null
          : await room.getEventById(credentials.inReplyTo!);
      txid ??= unsigned?.tryGet<String>('transaction_id');
      return await room.sendFileEvent(
        file,
        txid: txid,
        thumbnail: thumbnail,
        inReplyTo: inReplyTo,
        editEventId: credentials.editEventId,
        shrinkImageMaxDimension: credentials.shrinkImageMaxDimension,
        extraContent: credentials.extraContent,
      );
    }

    // we do not remove the event here. It will automatically be updated
    // in the `sendEvent` method to transition -1 -> 0 -> 1 -> 2
    return await room.sendEvent(
      content,
      txid: txid ?? unsigned?.tryGet<String>('transaction_id') ?? eventId,
    );
  }

  /// Whether the client is allowed to redact this event.
  bool get canRedact => senderId == room.client.userID || room.canRedact;

  /// Redacts this event. Throws `ErrorResponse` on error.
  Future<String?> redactEvent({String? reason, String? txid}) async =>
      await room.redactEvent(eventId, reason: reason, txid: txid);

  /// Searches for the reply event in the given timeline.
  Future<Event?> getReplyEvent(Timeline timeline) async {
    if (relationshipType != RelationshipTypes.reply) return null;
    final relationshipEventId = this.relationshipEventId;
    return relationshipEventId == null
        ? null
        : await timeline.getEventById(relationshipEventId);
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

    final sessionId = content.tryGet<String>('session_id');
    final senderKey = content.tryGet<String>('sender_key');
    if (sessionId == null || senderKey == null) {
      throw ('Unknown session_id or sender_key');
    }
    await room.requestSessionKey(sessionId, senderKey);
    return;
  }

  /// Gets the info map of file events, or a blank map if none present
  Map get infoMap =>
      content.tryGetMap<String, Object?>('info') ?? <String, Object?>{};

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

  /// Gets the mimetype of the attachment of a file event, or a blank string if not present
  String get attachmentMimetype => infoMap['mimetype'] is String
      ? infoMap['mimetype'].toLowerCase()
      : (content
              .tryGetMap<String, Object?>('file')
              ?.tryGet<String>('mimetype') ??
          '');

  /// Gets the mimetype of the thumbnail of a file event, or a blank string if not present
  String get thumbnailMimetype => thumbnailInfoMap['mimetype'] is String
      ? thumbnailInfoMap['mimetype'].toLowerCase()
      : (infoMap['thumbnail_file'] is Map &&
              infoMap['thumbnail_file']['mimetype'] is String
          ? infoMap['thumbnail_file']['mimetype']
          : '');

  /// Gets the underlying mxc url of an attachment of a file event, or null if not present
  Uri? get attachmentMxcUrl {
    final url = isAttachmentEncrypted
        ? (content.tryGetMap<String, Object?>('file')?['url'])
        : content['url'];
    return url is String ? Uri.tryParse(url) : null;
  }

  /// Gets the underlying mxc url of a thumbnail of a file event, or null if not present
  Uri? get thumbnailMxcUrl {
    final url = isThumbnailEncrypted
        ? infoMap['thumbnail_file']['url']
        : infoMap['thumbnail_url'];
    return url is String ? Uri.tryParse(url) : null;
  }

  /// Gets the mxc url of an attachment/thumbnail of a file event, taking sizes into account, or null if not present
  Uri? attachmentOrThumbnailMxcUrl({bool getThumbnail = false}) {
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
  Uri? getAttachmentUrl(
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
    if (mxcUrl == null) {
      throw "This event hasn't any attachment or thumbnail.";
    }
    getThumbnail = mxcUrl != attachmentMxcUrl;
    // Is this file storeable?
    final thisInfoMap = getThumbnail ? thumbnailInfoMap : infoMap;
    final database = room.client.database;
    if (database == null) {
      return false;
    }

    final storeable = thisInfoMap['size'] is int &&
        thisInfoMap['size'] <= database.maxFileSize;

    Uint8List? uint8list;
    if (storeable) {
      uint8list = await database.getFile(mxcUrl);
    }
    return uint8list != null;
  }

  /// Downloads (and decrypts if necessary) the attachment of this
  /// event and returns it as a [MatrixFile]. If this event doesn't
  /// contain an attachment, this throws an error. Set [getThumbnail] to
  /// true to download the thumbnail instead. Set [fromLocalStoreOnly] to true
  /// if you want to retrieve the attachment from the local store only without
  /// making http request.
  Future<MatrixFile> downloadAndDecryptAttachment(
      {bool getThumbnail = false,
      Future<Uint8List> Function(Uri)? downloadCallback,
      bool fromLocalStoreOnly = false}) async {
    if (![EventTypes.Message, EventTypes.Sticker].contains(type)) {
      throw ("This event has the type '$type' and so it can't contain an attachment.");
    }
    if (status.isSending) {
      final localFile = room.sendingFilePlaceholders[eventId];
      if (localFile != null) return localFile;
    }
    final database = room.client.database;
    final mxcUrl = attachmentOrThumbnailMxcUrl(getThumbnail: getThumbnail);
    if (mxcUrl == null) {
      throw "This event hasn't any attachment or thumbnail.";
    }
    getThumbnail = mxcUrl != attachmentMxcUrl;
    final isEncrypted =
        getThumbnail ? isThumbnailEncrypted : isAttachmentEncrypted;
    if (isEncrypted && !room.client.encryptionEnabled) {
      throw ('Encryption is not enabled in your Client.');
    }

    // Is this file storeable?
    final thisInfoMap = getThumbnail ? thumbnailInfoMap : infoMap;
    var storeable = database != null &&
        thisInfoMap['size'] is int &&
        thisInfoMap['size'] <= database.maxFileSize;

    Uint8List? uint8list;
    if (storeable) {
      uint8list = await room.client.database?.getFile(mxcUrl);
    }

    // Download the file
    final canDownloadFileFromServer = uint8list == null && !fromLocalStoreOnly;
    if (canDownloadFileFromServer) {
      final httpClient = room.client.httpClient;
      downloadCallback ??=
          (Uri url) async => (await httpClient.get(url)).bodyBytes;
      uint8list = await downloadCallback(mxcUrl.getDownloadLink(room.client));
      storeable = database != null &&
          storeable &&
          uint8list.lengthInBytes < database.maxFileSize;
      if (storeable) {
        await database.storeFile(
            mxcUrl, uint8list, DateTime.now().millisecondsSinceEpoch);
      }
    } else if (uint8list == null) {
      throw ('Unable to download file from local store.');
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
      uint8list =
          await room.client.nativeImplementations.decryptFile(encryptedFile);
      if (uint8list == null) {
        throw ('Unable to decrypt file');
      }
    }
    return MatrixFile(bytes: uint8list, name: body);
  }

  /// Returns if this is a known event type.
  bool get isEventTypeKnown =>
      EventLocalizations.localizationsMap.containsKey(type);

  /// Returns a localized String representation of this event. For a
  /// room list you may find [withSenderNamePrefix] useful. Set [hideReply] to
  /// crop all lines starting with '>'. With [plaintextBody] it'll use the
  /// plaintextBody instead of the normal body.
  /// [removeMarkdown] allow to remove the markdown formating from the event body.
  /// Usefull form message preview or notifications text.
  Future<String> calcLocalizedBody(MatrixLocalizations i18n,
      {bool withSenderNamePrefix = false,
      bool hideReply = false,
      bool hideEdit = false,
      bool plaintextBody = false,
      bool removeMarkdown = false}) async {
    if (redacted) {
      await redactedBecause?.fetchSenderUser();
    }

    if (withSenderNamePrefix &&
        (type == EventTypes.Message || type.contains(EventTypes.Encrypted))) {
      // To be sure that if the event need to be localized, the user is in memory.
      // used by EventLocalizations._localizedBodyNormalMessage
      await fetchSenderUser();
    }

    return calcLocalizedBodyFallback(i18n,
        withSenderNamePrefix: withSenderNamePrefix,
        hideReply: hideReply,
        hideEdit: hideEdit,
        plaintextBody: plaintextBody,
        removeMarkdown: removeMarkdown);
  }

  @Deprecated('Use calcLocalizedBody or calcLocalizedBodyFallback')
  String getLocalizedBody(MatrixLocalizations i18n,
          {bool withSenderNamePrefix = false,
          bool hideReply = false,
          bool hideEdit = false,
          bool plaintextBody = false,
          bool removeMarkdown = false}) =>
      calcLocalizedBodyFallback(i18n,
          withSenderNamePrefix: withSenderNamePrefix,
          hideReply: hideReply,
          hideEdit: hideEdit,
          plaintextBody: plaintextBody,
          removeMarkdown: removeMarkdown);

  /// Works similar to `calcLocalizedBody()` but does not wait for the sender
  /// user to be fetched. If it is not in the cache it will just use the
  /// fallback and display the localpart of the MXID according to the
  /// values of `formatLocalpart` and `mxidLocalPartFallback` in the `Client`
  /// class.
  String calcLocalizedBodyFallback(MatrixLocalizations i18n,
      {bool withSenderNamePrefix = false,
      bool hideReply = false,
      bool hideEdit = false,
      bool plaintextBody = false,
      bool removeMarkdown = false}) {
    if (redacted) {
      return i18n.removedBy(this);
    }

    final body = calcUnlocalizedBody(
      hideReply: hideReply,
      hideEdit: hideEdit,
      plaintextBody: plaintextBody,
      removeMarkdown: removeMarkdown,
    );

    final callback = EventLocalizations.localizationsMap[type];
    var localizedBody = i18n.unknownEvent(type);
    if (callback != null) {
      localizedBody = callback(this, i18n, body);
    }

    // Add the sender name prefix
    if (withSenderNamePrefix &&
        type == EventTypes.Message &&
        textOnlyMessageTypes.contains(messageType)) {
      final senderNameOrYou = senderId == room.client.userID
          ? i18n.you
          : senderFromMemoryOrFallback.calcDisplayname(i18n: i18n);
      localizedBody = '$senderNameOrYou: $localizedBody';
    }

    return localizedBody;
  }

  /// Calculating the body of an event regardless of localization.
  String calcUnlocalizedBody(
      {bool hideReply = false,
      bool hideEdit = false,
      bool plaintextBody = false,
      bool removeMarkdown = false}) {
    if (redacted) {
      return 'Removed by ${senderFromMemoryOrFallback.displayName ?? senderId}';
    }
    var body = plaintextBody ? this.plaintextBody : this.body;

    // we need to know if the message is an html message to be able to determine
    // if we need to strip the reply fallback.
    var htmlMessage = content['format'] != 'org.matrix.custom.html';
    // If we have an edit, we want to operate on the new content
    final newContent = content.tryGetMap<String, Object?>('m.new_content');
    if (hideEdit &&
        relationshipType == RelationshipTypes.edit &&
        newContent != null) {
      if (plaintextBody && newContent['format'] == 'org.matrix.custom.html') {
        htmlMessage = true;
        body = HtmlToText.convert(
            newContent.tryGet<String>('formatted_body') ?? formattedText);
      } else {
        htmlMessage = false;
        body = newContent.tryGet<String>('body') ?? body;
      }
    }
    // Hide reply fallback
    // Be sure that the plaintextBody already stripped teh reply fallback,
    // if the message is formatted
    if (hideReply && (!plaintextBody || htmlMessage)) {
      body = body.replaceFirst(
          RegExp(r'^>( \*)? <[^>]+>[^\n\r]+\r?\n(> [^\n]*\r?\n)*\r?\n'), '');
    }

    // return the html tags free body
    if (removeMarkdown == true) {
      final html = markdown(body, convertLinebreaks: false);
      final document = parse(
        html,
      );
      body = document.documentElement?.text ?? body;
    }
    return body;
  }

  static const Set<String> textOnlyMessageTypes = {
    MessageTypes.Text,
    MessageTypes.Notice,
    MessageTypes.Emote,
    MessageTypes.None,
  };

  /// returns if this event matches the passed event or transaction id
  bool matchesEventOrTransactionId(String? search) {
    if (search == null) {
      return false;
    }
    if (eventId == search) {
      return true;
    }
    return unsigned?['transaction_id'] == search;
  }

  /// Get the relationship type of an event. `null` if there is none
  String? get relationshipType {
    final mRelatesTo = content.tryGetMap<String, Object?>('m.relates_to');
    if (mRelatesTo == null) {
      return null;
    }
    final relType = mRelatesTo.tryGet<String>('rel_type');
    if (relType == RelationshipTypes.thread) {
      return RelationshipTypes.thread;
    }

    if (mRelatesTo.containsKey('m.in_reply_to')) {
      return RelationshipTypes.reply;
    }
    return relType;
  }

  /// Get the event ID that this relationship will reference. `null` if there is none
  String? get relationshipEventId {
    final relatesToMap = content.tryGetMap<String, Object?>('m.relates_to');
    return relatesToMap?.tryGet<String>('event_id') ??
        relatesToMap
            ?.tryGetMap<String, Object?>('m.in_reply_to')
            ?.tryGet<String>('event_id');
  }

  /// Get whether this event has aggregated events from a certain [type]
  /// To be able to do that you need to pass a [timeline]
  bool hasAggregatedEvents(Timeline timeline, String type) =>
      timeline.aggregatedEvents[eventId]?.containsKey(type) == true;

  /// Get all the aggregated event objects for a given [type]. To be able to do this
  /// you have to pass a [timeline]
  Set<Event> aggregatedEvents(Timeline timeline, String type) =>
      timeline.aggregatedEvents[eventId]?[type] ?? <Event>{};

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
        allEditEvents.sort((a, b) => a.originServerTs.millisecondsSinceEpoch -
                    b.originServerTs.millisecondsSinceEpoch >
                0
            ? 1
            : -1);
        final rawEvent = allEditEvents.last.toJson();
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
  // (?:\x{00a9}|\x{00ae}|[\x{2600}-\x{27bf}]|[\x{2b00}-\x{2bff}]|\x{d83c}[\x{d000}-\x{dfff}]|\x{d83d}[\x{d000}-\x{dfff}]|\x{d83e}[\x{d000}-\x{dfff}])[\x{fe00}-\x{fe0f}]?
  // we need to replace \x{0000} with \u0000, the comment is left in the other format to be able to paste into regex101.com
  // to see if there is a custom emote, we use the following regex: <img[^>]+data-mx-(?:emote|emoticon)(?==|>|\s)[^>]*>
  // now we combind the two to have four regexes:
  // 1. are there only emoji, or whitespace
  // 2. are there only emoji, emotes, or whitespace
  // 3. count number of emoji
  // 4- count number of emoji or emotes
  static final RegExp _onlyEmojiRegex = RegExp(
      r'^((?:\u00a9|\u00ae|[\u2600-\u27bf]|[\u2b00-\u2bff]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])[\ufe00-\ufe0f]?|\s)*$',
      caseSensitive: false,
      multiLine: false);
  static final RegExp _onlyEmojiEmoteRegex = RegExp(
      r'^((?:\u00a9|\u00ae|[\u2600-\u27bf]|[\u2b00-\u2bff]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])[\ufe00-\ufe0f]?|<img[^>]+data-mx-(?:emote|emoticon)(?==|>|\s)[^>]*>|\s)*$',
      caseSensitive: false,
      multiLine: false);
  static final RegExp _countEmojiRegex = RegExp(
      r'((?:\u00a9|\u00ae|[\u2600-\u27bf]|[\u2b00-\u2bff]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])[\ufe00-\ufe0f]?)',
      caseSensitive: false,
      multiLine: false);
  static final RegExp _countEmojiEmoteRegex = RegExp(
      r'((?:\u00a9|\u00ae|[\u2600-\u27bf]|[\u2b00-\u2bff]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])[\ufe00-\ufe0f]?|<img[^>]+data-mx-(?:emote|emoticon)(?==|>|\s)[^>]*>)',
      caseSensitive: false,
      multiLine: false);

  /// Returns if a given event only has emotes, emojis or whitespace as content.
  /// If the body contains a reply then it is stripped.
  /// This is useful to determine if stand-alone emotes should be displayed bigger.
  bool get onlyEmotes {
    if (isRichMessage) {
      final formattedTextStripped = formattedText.replaceAll(
          RegExp('<mx-reply>.*</mx-reply>',
              caseSensitive: false, multiLine: false, dotAll: true),
          '');
      return _onlyEmojiEmoteRegex.hasMatch(formattedTextStripped);
    } else {
      return _onlyEmojiRegex.hasMatch(plaintextBody);
    }
  }

  /// Gets the number of emotes in a given message. This is useful to determine
  /// if the emotes should be displayed bigger.
  /// If the body contains a reply then it is stripped.
  /// WARNING: This does **not** test if there are only emotes. Use `event.onlyEmotes` for that!
  int get numberEmotes {
    if (isRichMessage) {
      final formattedTextStripped = formattedText.replaceAll(
          RegExp('<mx-reply>.*</mx-reply>',
              caseSensitive: false, multiLine: false, dotAll: true),
          '');
      return _countEmojiEmoteRegex.allMatches(formattedTextStripped).length;
    } else {
      return _countEmojiRegex.allMatches(plaintextBody).length;
    }
  }

  /// If this event is in Status SENDING and it aims to send a file, then this
  /// shows the status of the file sending.
  FileSendingStatus? get fileSendingStatus {
    final status = unsigned?.tryGet<String>(fileSendingStatusKey);
    if (status == null) return null;
    return FileSendingStatus.values.singleWhereOrNull(
        (fileSendingStatus) => fileSendingStatus.name == status);
  }
}

enum FileSendingStatus {
  generatingThumbnail,
  encrypting,
  uploading,
}
