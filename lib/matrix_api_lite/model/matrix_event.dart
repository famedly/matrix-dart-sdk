// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite/model/stripped_state_event.dart';
import 'package:matrix/matrix_api_lite/utils/map_copy_extension.dart';

class MatrixEvent extends StrippedStateEvent {
  String eventId;
  String? roomId;
  DateTime originServerTs;
  Map<String, Object?>? unsigned;
  Map<String, Object?>? prevContent;
  String? redacts;

  MatrixEvent({
    required super.type,
    required super.content,
    required super.senderId,
    super.stateKey,
    required this.eventId,
    this.roomId,
    required this.originServerTs,
    this.unsigned,
    this.prevContent,
    this.redacts,
  });

  MatrixEvent.fromJson(super.json)
      : eventId = json['event_id'] as String,
        roomId = json['room_id'] as String?,
        originServerTs = DateTime.fromMillisecondsSinceEpoch(
          json['origin_server_ts'] as int,
        ),
        unsigned = (json['unsigned'] as Map<String, Object?>?)?.copy(),
        prevContent = (json['prev_content'] as Map<String, Object?>?)?.copy(),
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
    if (prevContent != null) {
      data['prev_content'] = prevContent;
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
