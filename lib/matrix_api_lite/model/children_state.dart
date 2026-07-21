// SPDX-FileCopyrightText: 2019-Present, 2022 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite/model/stripped_state_event.dart';

class ChildrenState extends StrippedStateEvent {
  DateTime originServerTs;

  ChildrenState({
    required super.type,
    required super.content,
    required super.senderId,
    required String super.stateKey,
    required this.originServerTs,
  });

  ChildrenState.fromJson(super.json)
    : originServerTs = DateTime.fromMillisecondsSinceEpoch(
        json['origin_server_ts'] as int,
      ),
      super.fromJson();

  @override
  Map<String, Object?> toJson() {
    final data = super.toJson();
    data['origin_server_ts'] = originServerTs.millisecondsSinceEpoch;
    return data;
  }
}
