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

import 'profile.dart';

class UserSearchResult {
  List<Profile> results;
  bool limited;

  UserSearchResult.fromJson(Map<String, dynamic> json) {
    results = <Profile>[];
    json['results'].forEach((v) {
      results.add(Profile.fromJson(v));
    });

    limited = json['limited'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['results'] = results.map((v) => v.toJson()).toList();

    data['limited'] = limited;
    return data;
  }
}
