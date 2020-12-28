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

class EventContext {
  String end;
  List<MatrixEvent> eventsAfter;
  MatrixEvent event;
  List<MatrixEvent> eventsBefore;
  String start;
  List<MatrixEvent> state;

  EventContext.fromJson(Map<String, dynamic> json) {
    end = json['end'];
    if (json['events_after'] != null) {
      eventsAfter = <MatrixEvent>[];
      json['events_after'].forEach((v) {
        eventsAfter.add(MatrixEvent.fromJson(v));
      });
    }
    event = json['event'] != null ? MatrixEvent.fromJson(json['event']) : null;
    if (json['events_before'] != null) {
      eventsBefore = <MatrixEvent>[];
      json['events_before'].forEach((v) {
        eventsBefore.add(MatrixEvent.fromJson(v));
      });
    }
    start = json['start'];
    if (json['state'] != null) {
      state = <MatrixEvent>[];
      json['state'].forEach((v) {
        state.add(MatrixEvent.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (end != null) {
      data['end'] = end;
    }
    if (eventsAfter != null) {
      data['events_after'] = eventsAfter.map((v) => v.toJson()).toList();
    }
    if (event != null) {
      data['event'] = event.toJson();
    }
    if (eventsBefore != null) {
      data['events_before'] = eventsBefore.map((v) => v.toJson()).toList();
    }
    data['start'] = start;
    if (state != null) {
      data['state'] = state.map((v) => v.toJson()).toList();
    }
    return data;
  }
}
