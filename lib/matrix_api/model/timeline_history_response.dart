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

import 'matrix_event.dart';

class TimelineHistoryResponse {
  String start;
  String end;
  List<MatrixEvent> chunk;
  List<MatrixEvent> state;

  TimelineHistoryResponse.fromJson(Map<String, dynamic> json) {
    start = json['start'];
    end = json['end'];
    chunk = json['chunk'] != null
        ? (json['chunk'] as List).map((i) => MatrixEvent.fromJson(i)).toList()
        : null;
    state = json['state'] != null
        ? (json['state'] as List).map((i) => MatrixEvent.fromJson(i)).toList()
        : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (start != null) data['start'] = start;
    if (end != null) data['end'] = end;
    if (chunk != null) data['chunk'] = chunk.map((i) => i.toJson());
    if (state != null) data['state'] = state.map((i) => i.toJson());
    return data;
  }
}
