// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';
import 'package:test/test.dart';

import 'fake_client.dart';

void main() {
  test('sync does not long-poll right after a failed sync', () async {
    final client = await getClient();
    client.syncErrorTimeoutSec = 0;
    final api = FakeMatrixApi.currentApi!;
    List<Object?> syncTimeouts() => FakeMatrixApi.calledEndpoints.entries
        .where((e) => e.key.startsWith('/client/v3/sync'))
        .expand((e) => e.value)
        .map((query) => (query as Map)['timeout'])
        .toList();

    const server = 'https://fakeserver.notexisting';
    api.servers.remove(server);
    final error = client.onSyncStatus.stream.firstWhere(
      (s) => s.status == SyncStatus.error,
    );
    await client.oneShotSync();
    await error;
    api.servers.add(server);

    FakeMatrixApi.calledEndpoints.clear();
    await client.oneShotSync();
    expect(syncTimeouts(), ['0']);

    FakeMatrixApi.calledEndpoints.clear();
    await client.oneShotSync();
    expect(syncTimeouts(), ['30000']);

    await client.dispose(closeDatabase: true);
  });
}
