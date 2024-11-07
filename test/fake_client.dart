/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020 Famedly GmbH
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
import 'fake_database.dart';

const ssssPassphrase = 'nae7ahDiequ7ohniufah3ieS2je1thohX4xeeka7aixohsho9O';
const ssssKey = 'EsT9 RzbW VhPW yqNp cC7j ViiW 5TZB LuY4 ryyv 9guN Ysmr WDPH';

// key @test:fakeServer.notExisting
const pickledOlmAccount =
    'N2v1MkIFGcl0mQpo2OCwSopxPQJ0wnl7oe7PKiT4141AijfdTIhRu+ceXzXKy3Kr00nLqXtRv7kid6hU4a+V0rfJWLL0Y51+3Rp/ORDVnQy+SSeo6Fn4FHcXrxifJEJ0djla5u98fBcJ8BSkhIDmtXRPi5/oJAvpiYn+8zMjFHobOeZUAxYR0VfQ9JzSYBsSovoQ7uFkNks1M4EDUvHtuyg3RxViwdNxs3718fyAqQ/VSwbXsY0Nl+qQbF+nlVGHenGqk5SuNl1P6e1PzZxcR0IfXA94Xij1Ob5gDv5YH4UCn9wRMG0abZsQP0YzpDM0FLaHSCyo9i5JD/vMlhH+nZWrgAzPPCTNGYewNV8/h3c+VyJh8ZTx/fVi6Yq46Fv+27Ga2ETRZ3Qn+Oyx6dLBjnBZ9iUvIhqpe2XqaGA1PopOz8iDnaZitw';

/// only use `path` if you explicitly if you need a db on path instead of in mem
Future<Client> getClient({
  Duration sendTimelineEventTimeout = const Duration(minutes: 1),
  String? databasePath,
}) async {
  final client = Client(
    logLevel: Level.verbose,
    'testclient',
    httpClient: FakeMatrixApi(),
    databaseBuilder: (client) =>
        getDatabase(client, databasePath: databasePath),
    onSoftLogout: (client) => client.refreshAccessToken(),
    sendTimelineEventTimeout: sendTimelineEventTimeout,
  );
  FakeMatrixApi.client = client;
  await client.checkHomeserver(
    Uri.parse('https://fakeServer.notExisting'),
    checkWellKnown: false,
  );
  await client.init(
    newToken: 'abcd',
    newRefreshToken: 'refresh_abcd',
    newUserID: '@test:fakeServer.notExisting',
    newHomeserver: client.homeserver,
    newDeviceName: 'Text Matrix Client',
    newDeviceID: 'GHTYAJCE',
    newOlmAccount: pickledOlmAccount,
  );
  await Future.delayed(Duration(milliseconds: 10));
  await client.abortSync();
  return client;
}

Future<Client> getOtherClient() async {
  final client = Client(
    'othertestclient',
    httpClient: FakeMatrixApi(),
    databaseBuilder: getDatabase,
  );
  FakeMatrixApi.client = client;
  await client.checkHomeserver(
    Uri.parse('https://fakeServer.notExisting'),
    checkWellKnown: false,
  );
  await client.init(
    newToken: '1234',
    newUserID: '@test:fakeServer.notExisting',
    newHomeserver: client.homeserver,
    newDeviceName: 'Text Matrix Client',
    newDeviceID: 'OTHERDEVICE',
  );
  await Future.delayed(Duration(milliseconds: 10));
  return client;
}
