// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../utils/map_copy_extension.dart';
import 'matrix_id.dart';
import 'stripped_state_event.dart';

class MatrixEvent extends StrippedStateEvent {
  String eventId;
  String? roomId;
  DateTime originServerTs;
  Map<String, Object?>? unsigned;
  String? redacts;

  /// The validated room ID as a [RoomId], or null if unset or malformed.
  RoomId? get parsedRoomId => roomId != null ? RoomId.tryParse(roomId!) : null;

  set parsedRoomId(RoomId? room) {
    roomId = room?.value;
  }

  /// The validated event ID as an [EventId], or null if malformed or synthetic.
  EventId? get eventIdentifier =>
      eventId.isEmpty ? null : EventId.tryParse(eventId);

  set eventIdentifier(EventId id) {
    eventId = id.value;
  }

  /// The validated event ID that this event redacts, or null if unset or malformed.
  EventId? get redactsEventId =>
      redacts != null ? EventId.tryParse(redacts!) : null;

  set redactsEventId(EventId? id) {
    redacts = id?.value;
  }

  MatrixEvent({
    required super.type,
    required super.content,
    required super.senderId,
    super.stateKey,
    required this.eventId,
    this.roomId,
    required this.originServerTs,
    this.unsigned,
    this.redacts,
  });

  MatrixEvent.typed({
    required super.type,
    required super.content,
    required super.senderUserId,
    super.stateKey,
    required EventId eventIdentifier,
    RoomId? room,
    required this.originServerTs,
    this.unsigned,
    EventId? redacts,
  }) : eventId = eventIdentifier.value,
       roomId = room?.value,
       redacts = redacts?.value,
       super.typed();

  MatrixEvent.fromJson(super.json)
    : eventId = json['event_id'] as String,
      roomId = json['room_id'] as String?,
      originServerTs = DateTime.fromMillisecondsSinceEpoch(
        json['origin_server_ts'] as int,
      ),
      unsigned = (json['unsigned'] as Map<String, Object?>?)?.copy(),
      redacts = json['redacts'] as String?,
      super.fromJson();

  @override
  Map<String, Object?> toJson() {
    final data = super.toJson();
    data['event_id'] = eventId;
    data['origin_server_ts'] = originServerTs.millisecondsSinceEpoch;
    if (unsigned != null) {
      data['unsigned'] = unsigned;
    }
    if (roomId != null) {
      data['room_id'] = roomId;
    }
    if (data['state_key'] == null) {
      data.remove('state_key');
    }
    if (redacts != null) {
      data['redacts'] = redacts;
    }
    return data;
  }
}
