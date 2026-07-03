// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class RoomSummary {
  List<String>? mHeroes;
  int? mJoinedMemberCount;
  int? mInvitedMemberCount;

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
