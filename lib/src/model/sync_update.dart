
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

import 'basic_event.dart';
import 'basic_event_with_sender.dart';
import 'basic_room_event.dart';
import 'matrix_event.dart';
import 'presence.dart';
import 'room_summary.dart';
import 'stripped_state_event.dart';

class SyncUpdate {
  String nextBatch;
  RoomsUpdate? rooms;
  List<Presence>? presence;
  List<BasicEvent>? accountData;
  List<BasicEventWithSender>? toDevice;
  DeviceListsUpdate? deviceLists;
  Map<String, int>? deviceOneTimeKeysCount;
  List<String>? deviceUnusedFallbackKeyTypes;

  SyncUpdate();

  SyncUpdate.fromJson(Map<String, dynamic> json)
      : nextBatch = json['next_batch'],
        rooms =
            json['rooms'] != null ? RoomsUpdate.fromJson(json['rooms']) : null,
        presence =
            (json['presence'] != null && json['presence']['events'] != null)
                ? (json['presence']['events'] as List)
                    .map((i) => Presence.fromJson(i))
                    .toList()
                : null,
        accountData = (json['account_data'] != null &&
                json['account_data']['events'] != null)
            ? (json['account_data']['events'] as List)
                .map((i) => BasicEvent.fromJson(i))
                .toList()
            : null,
        toDevice =
            (json['to_device'] != null && json['to_device']['events'] != null)
                ? (json['to_device']['events'] as List)
                    .map((i) => BasicEventWithSender.fromJson(i))
                    .toList()
                : null,
        deviceLists = json['device_lists'] != null
            ? DeviceListsUpdate.fromJson(json['device_lists'])
            : null,
        deviceOneTimeKeysCount = json['device_one_time_keys_count'] != null
            ? Map<String, int>.from(json['device_one_time_keys_count'])
            : null,
        deviceUnusedFallbackKeyTypes = (json[
                        'device_unused_fallback_key_types'] ??
                    json[
                        'org.matrix.msc2732.device_unused_fallback_key_types']) !=
                null
            ? List<String>.from(json['device_unused_fallback_key_types'] ??
                json['org.matrix.msc2732.device_unused_fallback_key_types'])
            : null;

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['next_batch'] = nextBatch;
    if (rooms != null) {
      data['rooms'] = rooms!.toJson();
    }
    if (presence != null) {
      data['presence'] = {
        'events': presence!.map((i) => i.toJson()).toList(),
      };
    }
    if (accountData != null) {
      data['account_data'] = {
        'events': accountData!.map((i) => i.toJson()).toList(),
      };
    }
    if (toDevice != null) {
      data['to_device'] = {
        'events': toDevice!.map((i) => i.toJson()).toList(),
      };
    }
    if (deviceLists != null) {
      data['device_lists'] = deviceLists!.toJson();
    }
    if (deviceOneTimeKeysCount != null) {
      data['device_one_time_keys_count'] = deviceOneTimeKeysCount;
    }
    if (deviceUnusedFallbackKeyTypes != null) {
      data['device_unused_fallback_key_types'] = deviceUnusedFallbackKeyTypes;
      data['org.matrix.msc2732.device_unused_fallback_key_types'] =
          deviceUnusedFallbackKeyTypes;
    }
    return data;
  }
}

class RoomsUpdate {
  Map<String, JoinedRoomUpdate>? join;
  Map<String, InvitedRoomUpdate>? invite;
  Map<String, LeftRoomUpdate>? leave;

  RoomsUpdate();

  RoomsUpdate.fromJson(Map<String, dynamic> json) {
    join = json['join'] != null
        ? (json['join'] as Map)
            .map((k, v) => MapEntry(k, JoinedRoomUpdate.fromJson(v)))
        : null;
    invite = json['invite'] != null
        ? (json['invite'] as Map)
            .map((k, v) => MapEntry(k, InvitedRoomUpdate.fromJson(v)))
        : null;
    leave = json['leave'] != null
        ? (json['leave'] as Map)
            .map((k, v) => MapEntry(k, LeftRoomUpdate.fromJson(v)))
        : null;
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (join != null) {
      data['join'] = join!.map((k, v) => MapEntry(k, v.toJson()));
    }
    if (invite != null) {
      data['invite'] = invite!.map((k, v) => MapEntry(k, v.toJson()));
    }
    if (leave != null) {
      data['leave'] = leave!.map((k, v) => MapEntry(k, v.toJson()));
    }
    return data;
  }
}

abstract class SyncRoomUpdate {}

class JoinedRoomUpdate extends SyncRoomUpdate {
  RoomSummary? summary;
  List<MatrixEvent>? state;
  TimelineUpdate? timeline;
  List<BasicRoomEvent>? ephemeral;
  List<BasicRoomEvent>? accountData;
  UnreadNotificationCounts? unreadNotifications;

  JoinedRoomUpdate();

  JoinedRoomUpdate.fromJson(Map<String, dynamic> json) {
    summary =
        json['summary'] != null ? RoomSummary.fromJson(json['summary']) : null;
    state = (json['state'] != null && json['state']['events'] != null)
        ? (json['state']['events'] as List)
            .map((i) => MatrixEvent.fromJson(i))
            .toList()
        : null;
    timeline = json['timeline'] != null
        ? TimelineUpdate.fromJson(json['timeline'])
        : null;

    ephemeral =
        (json['ephemeral'] != null && json['ephemeral']['events'] != null)
            ? (json['ephemeral']['events'] as List)
                .map((i) => BasicRoomEvent.fromJson(i))
                .toList()
            : null;
    accountData =
        (json['account_data'] != null && json['account_data']['events'] != null)
            ? (json['account_data']['events'] as List)
                .map((i) => BasicRoomEvent.fromJson(i))
                .toList()
            : null;
    unreadNotifications = json['unread_notifications'] != null
        ? UnreadNotificationCounts.fromJson(json['unread_notifications'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (summary != null) {
      data['summary'] = summary!.toJson();
    }
    if (state != null) {
      data['state'] = {
        'events': state!.map((i) => i.toJson()).toList(),
      };
    }
    if (timeline != null) {
      data['timeline'] = timeline!.toJson();
    }
    if (ephemeral != null) {
      data['ephemeral'] = {
        'events': ephemeral!.map((i) => i.toJson()).toList(),
      };
    }
    if (accountData != null) {
      data['account_data'] = {
        'events': accountData!.map((i) => i.toJson()).toList(),
      };
    }
    if (unreadNotifications != null) {
      data['unread_notifications'] = unreadNotifications!.toJson();
    }
    return data;
  }
}

class InvitedRoomUpdate extends SyncRoomUpdate {
  List<StrippedStateEvent>? inviteState;
  InvitedRoomUpdate.fromJson(Map<String, dynamic> json) {
    inviteState =
        (json['invite_state'] != null && json['invite_state']['events'] != null)
            ? (json['invite_state']['events'] as List)
                .map((i) => StrippedStateEvent.fromJson(i))
                .toList()
            : null;
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (inviteState != null) {
      data['invite_state'] = {
        'events': inviteState!.map((i) => i.toJson()).toList(),
      };
    }
    return data;
  }
}

class LeftRoomUpdate extends SyncRoomUpdate {
  List<MatrixEvent>? state;
  TimelineUpdate? timeline;
  List<BasicRoomEvent>? accountData;

  LeftRoomUpdate();

  LeftRoomUpdate.fromJson(Map<String, dynamic> json) {
    state = (json['state'] != null && json['state']['events'] != null)
        ? (json['state']['events'] as List)
            .map((i) => MatrixEvent.fromJson(i))
            .toList()
        : null;
    timeline = json['timeline'] != null
        ? TimelineUpdate.fromJson(json['timeline'])
        : null;
    accountData =
        (json['account_data'] != null && json['account_data']['events'] != null)
            ? (json['account_data']['events'] as List)
                .map((i) => BasicRoomEvent.fromJson(i))
                .toList()
            : null;
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (state != null) {
      data['state'] = {
        'events': state!.map((i) => i.toJson()).toList(),
      };
    }
    if (timeline != null) {
      data['timeline'] = timeline!.toJson();
    }
    if (accountData != null) {
      data['account_data'] = {
        'events': accountData!.map((i) => i.toJson()).toList(),
      };
    }
    return data;
  }
}

class TimelineUpdate {
  List<MatrixEvent>? events;
  bool? limited;
  String? prevBatch;

  TimelineUpdate();

  TimelineUpdate.fromJson(Map<String, dynamic> json) {
    events = json['events'] != null
        ? (json['events'] as List).map((i) => MatrixEvent.fromJson(i)).toList()
        : null;
    limited = json['limited'];
    prevBatch = json['prev_batch'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (events != null) {
      data['events'] = events!.map((i) => i.toJson()).toList();
    }
    if (limited != null) {
      data['limited'] = limited;
    }
    if (prevBatch != null) {
      data['prev_batch'] = prevBatch;
    }
    return data;
  }
}

class UnreadNotificationCounts {
  int? highlightCount;
  int? notificationCount;
  UnreadNotificationCounts.fromJson(Map<String, dynamic> json) {
    highlightCount = json['highlight_count'];
    notificationCount = json['notification_count'];
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (highlightCount != null) {
      data['highlight_count'] = highlightCount;
    }
    if (notificationCount != null) {
      data['notification_count'] = notificationCount;
    }
    return data;
  }
}

class DeviceListsUpdate {
  List<String>? changed;
  List<String>? left;
  DeviceListsUpdate.fromJson(Map<String, dynamic> json) {
    changed = List<String>.from(json['changed'] ?? []);
    left = List<String>.from(json['left'] ?? []);
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (changed != null) {
      data['changed'] = changed;
    }
    if (left != null) {
      data['left'] = left;
    }
    return data;
  }
}
