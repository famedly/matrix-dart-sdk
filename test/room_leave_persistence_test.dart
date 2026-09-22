// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

// Regression tests for left rooms coming back as joined after a restart: the
// room was dropped from `Client.rooms` so the running session looked correct,
// but its database row kept `membership: join`. The next launch loaded it as a
// normal joined chat and sending into it failed with `M_FORBIDDEN`.

import 'package:collection/collection.dart';
import 'package:matrix/matrix.dart';
import 'package:test/test.dart';

import 'fake_client.dart';

void main() {
  group('Leave persistence', () {
    const roomId = '!leftRoom:example.com';

    late Client client;

    setUp(() async {
      client = await getClient();
      Logs().level = Level.error;
      await client.abortSync();
      client.rooms.clear();
      await client.database.clearCache();
    });

    tearDown(() async => client.dispose().onError((e, s) {}));

    /// The membership a fresh launch would see. `Client.init()` builds its room
    /// list from exactly this call, so whatever it returns survives a restart.
    Future<Membership?> membershipAfterRestart() async {
      final rooms = await client.database.getRoomList(client);
      return rooms.firstWhereOrNull((room) => room.id == roomId)?.membership;
    }

    Future<void> syncJoin() => client.handleSync(
      SyncUpdate(
        nextBatch: 'join',
        rooms: RoomsUpdate(join: {roomId: JoinedRoomUpdate()}),
      ),
    );

    Future<void> syncLeave() => client.handleSync(
      SyncUpdate(
        nextBatch: 'leave',
        rooms: RoomsUpdate(leave: {roomId: LeftRoomUpdate()}),
      ),
    );

    test('known room is forgotten on leave without includeLeave', () async {
      await syncJoin();
      expect(await membershipAfterRestart(), Membership.join);

      await syncLeave();

      expect(client.getRoomById(roomId), null);
      expect(await membershipAfterRestart(), null);
    });

    test('known room is stored as left on leave with includeLeave', () async {
      client.syncFilter.room?.includeLeave = true;

      await syncJoin();
      expect(await membershipAfterRestart(), Membership.join);

      await syncLeave();

      expect(client.getRoomById(roomId)?.membership, Membership.leave);
      expect(await membershipAfterRestart(), Membership.leave);
    });

    // The two cases below always worked, which is part of why this hid for so
    // long: a leave for a room we never knew must not resurrect it, and with
    // includeLeave it is written by the "room does not exist yet" branch. A
    // test that only leaves an unknown room passes against the broken code.
    test('unknown room is not stored on leave without includeLeave', () async {
      await syncLeave();

      expect(await membershipAfterRestart(), null);
    });

    test('unknown room is stored as left on leave with includeLeave', () async {
      client.syncFilter.room?.includeLeave = true;

      await syncLeave();

      expect(await membershipAfterRestart(), Membership.leave);
    });
  });
}
