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

class RoomSummary {
  List<String> mHeroes;
  int mJoinedMemberCount;
  int mInvitedMemberCount;
  RoomSummary.fromJson(Map<String, dynamic> json) {
    mHeroes =
        json['m.heroes'] != null ? List<String>.from(json['m.heroes']) : null;
    mJoinedMemberCount = json['m.joined_member_count'];
    mInvitedMemberCount = json['m.invited_member_count'];
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
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
