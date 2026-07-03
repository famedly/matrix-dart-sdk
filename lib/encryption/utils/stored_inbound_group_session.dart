// SPDX-FileCopyrightText: 2019-Present, 2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class StoredInboundGroupSession {
  final String roomId;
  final String sessionId;
  final String pickle;
  final String content;
  final String indexes;
  final String allowedAtIndex;
  @Deprecated('Only in use in legacy databases!')
  final bool? uploaded;
  final String senderKey;
  final String senderClaimedKeys;

  StoredInboundGroupSession({
    required this.roomId,
    required this.sessionId,
    required this.pickle,
    required this.content,
    required this.indexes,
    required this.allowedAtIndex,
    @Deprecated('Only in use in legacy databases!') this.uploaded,
    required this.senderKey,
    required this.senderClaimedKeys,
  });

  factory StoredInboundGroupSession.fromJson(Map<String, dynamic> json) =>
      StoredInboundGroupSession(
        roomId: json['room_id'],
        sessionId: json['session_id'],
        pickle: json['pickle'],
        content: json['content'],
        indexes: json['indexes'],
        allowedAtIndex: json['allowed_at_index'],
        // ignore: deprecated_member_use_from_same_package
        uploaded: json['uploaded'],
        senderKey: json['sender_key'],
        senderClaimedKeys: json['sender_claimed_keys'],
      );

  Map<String, dynamic> toJson() => {
    'room_id': roomId,
    'session_id': sessionId,
    'pickle': pickle,
    'content': content,
    'indexes': indexes,
    'allowed_at_index': allowedAtIndex,
    // ignore: deprecated_member_use_from_same_package
    if (uploaded != null) 'uploaded': uploaded,
    'sender_key': senderKey,
    'sender_claimed_keys': senderClaimedKeys,
  };
}
