// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'matrix_id.dart';

class RoomSummary {
  List<String>? mHeroes;
  int? mJoinedMemberCount;
  int? mInvitedMemberCount;

  /// The validated hero user IDs for this room summary.
  List<UserId>? get heroes =>
      mHeroes?.map(UserId.tryParse).whereType<UserId>().toList();

  RoomSummary.fromJson(Map<String, Object?> json)
    : mHeroes = json['m.heroes'] != null
          ? List<String>.from(json['m.heroes'] as List)
          : null,
      mJoinedMemberCount = json['m.joined_member_count'] as int?,
      mInvitedMemberCount = json['m.invited_member_count'] as int?;

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    if (mHeroes != null) {
      data['m.heroes'] = mHeroes;
    }
    if (mJoinedMemberCount != null) {
      data['m.joined_member_count'] = mJoinedMemberCount;
    }
    if (mInvitedMemberCount != null) {
      data['m.invited_member_count'] = mInvitedMemberCount;
    }
    return data;
  }
}
