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

import 'package:matrix_api_lite/matrix_api_lite.dart';

class SyncUpdate {
  String nextBatch;
  RoomsUpdate? rooms;
  List<Presence>? presence;
  List<BasicEvent>? accountData;
  List<BasicEventWithSender>? toDevice;
  DeviceListsUpdate? deviceLists;
  Map<String, int>? deviceOneTimeKeysCount;
  List<String>? deviceUnusedFallbackKeyTypes;

  SyncUpdate({
    required this.nextBatch,
    this.rooms,
    this.presence,
    this.accountData,
    this.toDevice,
    this.deviceLists,
    this.deviceOneTimeKeysCount,
    this.deviceUnusedFallbackKeyTypes,
  });

  SyncUpdate.fromJson(Map<String, Object?> json)
      : nextBatch = json['next_batch'] as String,
        rooms = (() {
          final temp = json.tryGetMap<String, Object?>('rooms');
          return temp != null ? RoomsUpdate.fromJson(temp) : null;
        }()),
        presence = json
            .tryGetMap<String, List<dynamic>>('presence')?['events']
            ?.map((i) => Presence.fromJson(i as Map<String, Object?>))
            .toList(),
        accountData = json
            .tryGetMap<String, List<dynamic>>('account_data')?['events']
            ?.map((i) => BasicEvent.fromJson(i as Map<String, Object?>))
            .toList(),
        toDevice = json
            .tryGetMap<String, List<dynamic>>('to_device')?['events']
            ?.map(
                (i) => BasicEventWithSender.fromJson(i as Map<String, Object?>))
            .toList(),
        deviceLists = (() {
          final temp = json.tryGetMap<String, Object?>('device_lists');
          return temp != null ? DeviceListsUpdate.fromJson(temp) : null;
        }()),
        deviceOneTimeKeysCount =
            json.tryGetMap<String, int>('device_one_time_keys_count'),
        deviceUnusedFallbackKeyTypes =
            json.tryGetList<String>('device_unused_fallback_key_types') ??
                json.tryGetList<String>(
                    'org.matrix.msc2732.device_unused_fallback_key_types');

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
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

  RoomsUpdate({
    this.join,
    this.invite,
    this.leave,
  });

  RoomsUpdate.fromJson(Map<String, Object?> json) {
    join = json.tryGetMap<String, Object?>('join')?.catchMap((k, v) =>
        MapEntry(k, JoinedRoomUpdate.fromJson(v as Map<String, Object?>)));
    invite = json.tryGetMap<String, Object?>('invite')?.catchMap((k, v) =>
        MapEntry(k, InvitedRoomUpdate.fromJson(v as Map<String, Object?>)));
    leave = json.tryGetMap<String, Object?>('leave')?.catchMap((k, v) =>
        MapEntry(k, LeftRoomUpdate.fromJson(v as Map<String, Object?>)));
  }

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
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

  JoinedRoomUpdate({
    this.summary,
    this.state,
    this.timeline,
    this.ephemeral,
    this.accountData,
    this.unreadNotifications,
  });

  JoinedRoomUpdate.fromJson(Map<String, Object?> json)
      : summary = json.tryGetFromJson('summary', RoomSummary.fromJson),
        state = json
            .tryGetMap<String, List<dynamic>>('state')?['events']
            ?.map((i) => MatrixEvent.fromJson(i as Map<String, Object?>))
            .toList(),
        timeline = json.tryGetFromJson('timeline', TimelineUpdate.fromJson),
        ephemeral = json
            .tryGetMap<String, List<dynamic>>('ephemeral')?['events']
            ?.map((i) => BasicRoomEvent.fromJson(i as Map<String, Object?>))
            .toList(),
        accountData = json
            .tryGetMap<String, List<dynamic>>('account_data')?['events']
            ?.map((i) => BasicRoomEvent.fromJson(i as Map<String, Object?>))
            .toList(),
        unreadNotifications = json.tryGetFromJson(
            'unread_notifications', UnreadNotificationCounts.fromJson);

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
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

  InvitedRoomUpdate({this.inviteState});

  InvitedRoomUpdate.fromJson(Map<String, Object?> json)
      : inviteState = json
            .tryGetMap<String, List<dynamic>>('invite_state')?['events']
            ?.map((i) => StrippedStateEvent.fromJson(i as Map<String, Object?>))
            .toList();

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
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

  LeftRoomUpdate({
    this.state,
    this.timeline,
    this.accountData,
  });

  LeftRoomUpdate.fromJson(Map<String, Object?> json)
      : state = json
            .tryGetMap<String, List<dynamic>>('state')?['events']
            ?.map((i) => MatrixEvent.fromJson(i as Map<String, Object?>))
            .toList(),
        timeline = json.tryGetFromJson('timeline', TimelineUpdate.fromJson),
        accountData = json
            .tryGetMap<String, List<dynamic>>('account_data')?['events']
            ?.map((i) => BasicRoomEvent.fromJson(i as Map<String, Object?>))
            .toList();

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
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

  TimelineUpdate({
    this.events,
    this.limited,
    this.prevBatch,
  });

  TimelineUpdate.fromJson(Map<String, Object?> json)
      : events = json
            .tryGetList<Map<String, Object?>>('events')
            ?.map((v) => MatrixEvent.fromJson(v))
            .toList(),
        limited = json.tryGet<bool>('limited'),
        prevBatch = json.tryGet<String>('prev_batch');

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
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

  UnreadNotificationCounts({
    this.notificationCount,
    this.highlightCount,
  });

  UnreadNotificationCounts.fromJson(Map<String, Object?> json)
      : highlightCount = json.tryGet<int>('highlight_count'),
        notificationCount = json.tryGet<int>('notification_count');

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
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

  DeviceListsUpdate({
    this.changed,
    this.left,
  });

  DeviceListsUpdate.fromJson(Map<String, Object?> json)
      : changed = json.tryGetList<String>('changed') ?? [],
        left = json.tryGetList<String>('left') ?? [];

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    if (changed != null) {
      data['changed'] = changed;
    }
    if (left != null) {
      data['left'] = left;
    }
    return data;
  }
}
