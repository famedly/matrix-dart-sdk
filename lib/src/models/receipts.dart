/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020, 2021, 2023 Famedly GmbH
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

import 'package:matrix/matrix.dart';

// Receipts are pretty complicated nowadays. We basicaly have 3 different aspects, that we need to multiplex together:
// 1. A receipt can be public or private. Currently clients can send either a public one, a private one or both. This means you have 2 receipts for your own user and no way to know, which one is ahead!
// 2. A receipt can be for the normal timeline, but with threads they can also be for the main timeline (which is messages without thread ids) and for threads. So we have have 3 options there basically, with the last one being a thread for each thread id!
// 3. Edits can make the timeline non-linear, so receipts don't match the visual order.
// Additionally of course timestamps are usually not reliable, but we can probably assume they are correct for the same user unless their server had wrong clocks in between.
//
// So how do we solve that? Users of the SDK usually do one of these operations:
// - Check if the current user has read the last event in a room (usually in the global timeline, but also possibly in the main thread or a specific thread)
// - Check if the current users receipt is before or after the current event
// - List users that have read up to a certain point (possibly in a specific timeline?)
//
// One big simplification we could do, would be to always assume our own user sends a private receipt with their public one. This won't play nicely with other SDKs, but it would simplify our work a lot.
// If we don't do that, we have to compare receipts when updating them. This can be very annoying, because we can only compare event ids, if we have stored both of them, which we often have not.
// If we fall back to the timestamp then it will break if a user ever has a client sending laggy public receipts, i.e. sends public receipts at a later point for previous events, because it will move the read marker back.
// Here is how Element solves it: https://github.com/matrix-org/matrix-js-sdk/blob/da03c3b529576a8fcde6f2c9a171fa6cca012830/src/models/read-receipt.ts#L97
// Luckily that is only an issue for our own events. We can also assume, that if we only have one event in the database, that it is newer.

/// Represents a receipt.
/// This [user] has read an event at the given [time].
class Receipt {
  final User user;
  final DateTime time;

  const Receipt(this.user, this.time);

  @override
  bool operator ==(dynamic other) => (other is Receipt &&
      other.user == user &&
      other.time.millisecondsSinceEpoch == time.millisecondsSinceEpoch);

  @override
  int get hashCode => Object.hash(user, time);
}

class ReceiptData {
  int originServerTs;
  String? threadId;

  DateTime get timestamp => DateTime.fromMillisecondsSinceEpoch(originServerTs);

  ReceiptData(this.originServerTs, {this.threadId});
}

class ReceiptEventContent {
  Map<String, Map<ReceiptType, Map<String, ReceiptData>>> receipts;
  ReceiptEventContent(this.receipts);

  factory ReceiptEventContent.fromJson(Map<String, dynamic> json) {
    // Example data:
    // {
    //   "$I": {
    //     "m.read": {
    //       "@user:example.org": {
    //         "ts": 1661384801651,
    //         "thread_id": "main" // because `I` is not in a thread, but is a threaded receipt
    //       }
    //     }
    //   },
    //   "$E": {
    //     "m.read": {
    //       "@user:example.org": {
    //         "ts": 1661384801651,
    //         "thread_id": "$A" // because `E` is in Thread `A`
    //       }
    //     }
    //   },
    //   "$D": {
    //     "m.read": {
    //       "@user:example.org": {
    //         "ts": 1661384801651
    //         // no `thread_id` because the receipt is *unthreaded*
    //       }
    //     }
    //   }
    // }

    final Map<String, Map<ReceiptType, Map<String, ReceiptData>>> receipts = {};
    for (final eventIdEntry in json.entries) {
      final eventId = eventIdEntry.key;
      final contentForEventId = eventIdEntry.value;

      if (!eventId.startsWith('\$') || contentForEventId is! Map) continue;

      for (final receiptTypeEntry in contentForEventId.entries) {
        if (receiptTypeEntry.key is! String) continue;

        final receiptType = ReceiptType.values.fromString(receiptTypeEntry.key);
        final contentForReceiptType = receiptTypeEntry.value;

        if (receiptType == null || contentForReceiptType is! Map) continue;

        for (final userIdEntry in contentForReceiptType.entries) {
          final userId = userIdEntry.key;
          final receiptContent = userIdEntry.value;

          if (userId is! String ||
              !userId.isValidMatrixId ||
              receiptContent is! Map) continue;

          final ts = receiptContent['ts'];
          final threadId = receiptContent['thread_id'];

          if (ts is int && (threadId == null || threadId is String)) {
            ((receipts[eventId] ??= {})[receiptType] ??= {})[userId] =
                ReceiptData(ts, threadId: threadId);
          }
        }
      }
    }

    return ReceiptEventContent(receipts);
  }
}

class LatestReceiptStateData {
  String eventId;
  int ts;

  DateTime get timestamp => DateTime.fromMillisecondsSinceEpoch(ts);

  LatestReceiptStateData(this.eventId, this.ts);

  factory LatestReceiptStateData.fromJson(Map<String, dynamic> json) {
    return LatestReceiptStateData(json['e'], json['ts']);
  }

  Map<String, dynamic> toJson() => {
        // abbreviated names, because we will store a lot of these.
        'e': eventId,
        'ts': ts,
      };
}

class LatestReceiptStateForTimeline {
  LatestReceiptStateData? ownPrivate;
  LatestReceiptStateData? ownPublic;
  LatestReceiptStateData? latestOwnReceipt;

  Map<String, LatestReceiptStateData> otherUsers;

  LatestReceiptStateForTimeline({
    required this.ownPrivate,
    required this.ownPublic,
    required this.latestOwnReceipt,
    required this.otherUsers,
  });

  factory LatestReceiptStateForTimeline.empty() =>
      LatestReceiptStateForTimeline(
          ownPrivate: null,
          ownPublic: null,
          latestOwnReceipt: null,
          otherUsers: {});

  factory LatestReceiptStateForTimeline.fromJson(Map<String, dynamic> json) {
    final private = json['private'];
    final public = json['public'];
    final latest = json['latest'];
    final Map<String, dynamic>? others = json['others'];

    final Map<String, LatestReceiptStateData> byUser = others
            ?.map((k, v) => MapEntry(k, LatestReceiptStateData.fromJson(v))) ??
        {};

    return LatestReceiptStateForTimeline(
      ownPrivate:
          private != null ? LatestReceiptStateData.fromJson(private) : null,
      ownPublic:
          public != null ? LatestReceiptStateData.fromJson(public) : null,
      latestOwnReceipt:
          latest != null ? LatestReceiptStateData.fromJson(latest) : null,
      otherUsers: byUser,
    );
  }

  Map<String, dynamic> toJson() => {
        if (ownPrivate != null) 'private': ownPrivate!.toJson(),
        if (ownPublic != null) 'public': ownPublic!.toJson(),
        if (latestOwnReceipt != null) 'latest': latestOwnReceipt!.toJson(),
        'others': otherUsers.map((k, v) => MapEntry(k, v.toJson())),
      };
}

class LatestReceiptState {
  static const eventType = 'com.famedly.receipts_state';

  /// Receipts for no specific thread
  LatestReceiptStateForTimeline global;

  /// Receipt for the "main" thread, which is the global timeline without any thread events
  LatestReceiptStateForTimeline? mainThread;

  /// Receipts inside threads
  Map<String, LatestReceiptStateForTimeline> byThread;

  LatestReceiptState({
    required this.global,
    this.mainThread,
    this.byThread = const {},
  });

  factory LatestReceiptState.fromJson(Map<String, dynamic> json) {
    final global = json['global'] ?? <String, dynamic>{};
    final Map<String, dynamic> main = json['main'] ?? <String, dynamic>{};
    final Map<String, dynamic> byThread = json['thread'] ?? <String, dynamic>{};

    return LatestReceiptState(
      global: LatestReceiptStateForTimeline.fromJson(global),
      mainThread:
          main.isNotEmpty ? LatestReceiptStateForTimeline.fromJson(main) : null,
      byThread: byThread.map(
          (k, v) => MapEntry(k, LatestReceiptStateForTimeline.fromJson(v))),
    );
  }

  Map<String, dynamic> toJson() => {
        'global': global.toJson(),
        if (mainThread != null) 'main': mainThread!.toJson(),
        if (byThread.isNotEmpty)
          'thread': byThread.map((k, v) => MapEntry(k, v.toJson())),
      };

  Future<void> update(
    ReceiptEventContent content,
    Room room,
  ) async {
    final List<LatestReceiptStateForTimeline> updatedTimelines = [];
    final ownUserid = room.client.userID!;

    content.receipts.forEach((eventId, receiptsByType) {
      receiptsByType.forEach((receiptType, receiptsByUser) {
        receiptsByUser.forEach((user, receipt) {
          LatestReceiptStateForTimeline? timeline;
          final threadId = receipt.threadId;
          if (threadId == 'main') {
            timeline = (mainThread ??= LatestReceiptStateForTimeline.empty());
          } else if (threadId != null) {
            timeline =
                (byThread[threadId] ??= LatestReceiptStateForTimeline.empty());
          } else {
            timeline = global;
          }

          final receiptData =
              LatestReceiptStateData(eventId, receipt.originServerTs);
          if (user == ownUserid) {
            if (receiptType == ReceiptType.mReadPrivate) {
              timeline.ownPrivate = receiptData;
            } else if (receiptType == ReceiptType.mRead) {
              timeline.ownPublic = receiptData;
            }
            updatedTimelines.add(timeline);
          } else {
            timeline.otherUsers[user] = receiptData;
          }
        });
      });
    });

    // set the latest receipt to the one furthest down in the timeline, or if we don't know that, the newest ts.
    if (updatedTimelines.isEmpty) return;

    final eventOrder = await room.client.database?.getEventIdList(room) ?? [];

    for (final timeline in updatedTimelines) {
      if (timeline.ownPrivate?.eventId == timeline.ownPublic?.eventId) {
        if (timeline.ownPrivate != null) {
          timeline.latestOwnReceipt = timeline.ownPrivate;
        }
        continue;
      }

      final public = timeline.ownPublic;
      final private = timeline.ownPrivate;

      if (private == null) {
        timeline.latestOwnReceipt = public;
      } else if (public == null) {
        timeline.latestOwnReceipt = private;
      } else {
        final privatePos = eventOrder.indexOf(private.eventId);
        final publicPos = eventOrder.indexOf(public.eventId);

        if (publicPos < 0 ||
            privatePos <= publicPos ||
            (privatePos < 0 && private.ts > public.ts)) {
          timeline.latestOwnReceipt = private;
        } else {
          timeline.latestOwnReceipt = public;
        }
      }
    }
  }
}
