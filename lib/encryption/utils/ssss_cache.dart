// SPDX-FileCopyrightText: 2019-Present, 2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class SSSSCache {
  final String? type;
  final String? keyId;
  final String? ciphertext;
  final String? content;

  const SSSSCache({this.type, this.keyId, this.ciphertext, this.content});

  factory SSSSCache.fromJson(Map<String, dynamic> json) => SSSSCache(
        type: json['type'],
        keyId: json['key_id'],
        ciphertext: json['ciphertext'],
        content: json['content'],
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'key_id': keyId,
        'ciphertext': ciphertext,
        'content': content,
      };
}
