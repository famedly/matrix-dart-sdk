// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

// ignore_for_file: avoid_print

// Load test, not part of the suite: dart test -j 1 test/sync_load.dart

@TestOn('vm')
library;

import 'dart:io';

import 'package:matrix/matrix.dart';
import 'package:test/test.dart';

import 'fake_client.dart';

const rooms = 100;
const eventsPerRoom = 30;
const membersInFirstRoom = 1000;
const syncs = 20;

Map<String, Object?> member(int i) => {
  'type': 'm.room.member',
  'state_key': '@user$i:example.org',
  'sender': '@user$i:example.org',
  'event_id': '\$member$i',
  'origin_server_ts': 1700000000000,
  'content': {'membership': 'join', 'displayname': 'User $i'},
};

SyncUpdate syncUpdate(int n) => SyncUpdate.fromJson({
  'next_batch': 'batch$n',
  'rooms': {
    'join': {
      for (var r = 0; r < rooms; r++)
        '!room$r:example.org': {
          if (n == 0)
            'state': {
              'events': [
                for (var m = 0; m < (r == 0 ? membersInFirstRoom : 10); m++)
                  member(m),
              ],
            },
          'timeline': {
            'limited': false,
            'prev_batch': 'prev$n',
            'events': [
              for (var e = 0; e < eventsPerRoom; e++)
                {
                  'type': 'm.room.message',
                  'sender': '@user${e % 10}:example.org',
                  'event_id': '\$e${n}_${r}_$e',
                  'origin_server_ts': 1700000000000 + n * 1000 + e,
                  'content': {'msgtype': 'm.text', 'body': 'Sync $n event $e'},
                },
            ],
          },
          'unread_notifications': {'notification_count': n},
        },
    },
  },
});

void main() {
  test('L5 sync processing', () async {
    final dir = await Directory.systemTemp.createTemp('sync_load');
    final client = await getClient(databasePath: '${dir.path}/db.sqlite');
    final updates = [for (var n = 0; n < syncs; n++) syncUpdate(n)];
    final sw = Stopwatch()..start();
    for (final update in updates) {
      await client.database.transaction(() => client.handleSync(update));
    }
    print(
      'LOAD L5 $syncs syncs x $rooms rooms x $eventsPerRoom events '
      '${sw.elapsedMilliseconds} ms',
    );
    final room = client.getRoomById('!room0:example.org')!;
    final events = await client.database.getEventList(room, limit: 5);
    expect(events.first.eventId, '\$e${syncs - 1}_0_${eventsPerRoom - 1}');
    await client.dispose(closeDatabase: true);
    await dir.delete(recursive: true);
  });
}
