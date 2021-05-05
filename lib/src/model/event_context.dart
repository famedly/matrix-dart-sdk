/* MIT License
* 
* Copyright (C) 2019, 2020, 2021 Famedly GmbH
* 
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
* 
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
* 
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
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
      eventsAfter = (json['events_after'] as List)
          .map((v) => MatrixEvent.fromJson(v))
          .toList();
    }
    event = json['event'] != null ? MatrixEvent.fromJson(json['event']) : null;
    if (json['events_before'] != null) {
      eventsBefore = (json['events_before'] as List)
          .map((v) => MatrixEvent.fromJson(v))
          .toList();
    }
    start = json['start'];
    if (json['state'] != null) {
      state =
          (json['state'] as List).map((v) => MatrixEvent.fromJson(v)).toList();
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
