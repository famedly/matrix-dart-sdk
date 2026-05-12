// SPDX-FileCopyrightText: 2019, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

class QueuedToDeviceEvent {
  final int id;
  final String type;
  final String txnId;
  final Map<String, dynamic> content;

  QueuedToDeviceEvent({
    required this.id,
    required this.type,
    required this.txnId,
    required this.content,
  });

  factory QueuedToDeviceEvent.fromJson(Map<String, dynamic> json) =>
      QueuedToDeviceEvent(
        id: json['id'],
        type: json['type'],
        txnId: json['txn_id'],
        // Temporary fix to stay compatible to Moor AND a key value store
        content: json['content'] is String
            ? jsonDecode(json['content'])
            : json['content'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'txn_id': txnId,
        'content': content,
      };
}
