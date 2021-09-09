/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2021 Famedly GmbH
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

class SSSSCache {
  final int? clientId;
  final String? type;
  final String? keyId;
  final String? ciphertext;
  final String? content;

  const SSSSCache(
      {this.clientId, this.type, this.keyId, this.ciphertext, this.content});

  factory SSSSCache.fromJson(Map<String, dynamic> json) => SSSSCache(
        clientId: json['client_id'],
        type: json['type'],
        keyId: json['key_id'],
        ciphertext: json['ciphertext'],
        content: json['content'],
      );

  Map<String, dynamic> toJson() => {
        'client_id': clientId,
        'type': type,
        'key_id': keyId,
        'ciphertext': ciphertext,
        'content': content,
      };
}
