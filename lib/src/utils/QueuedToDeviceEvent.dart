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
import 'dart:convert';

class QueuedToDeviceEvent {
  final int id;
  final String type;
  final String txnId;
  final Map<String, dynamic> content;

  QueuedToDeviceEvent({this.id, this.type, this.txnId, this.content});

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
