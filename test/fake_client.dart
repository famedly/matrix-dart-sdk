/*
 *   Ansible inventory script used at Famedly GmbH for managing many hosts
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

import 'package:famedlysdk/famedlysdk.dart';

import 'fake_matrix_api.dart';
import 'fake_database.dart';

// key @test:fakeServer.notExisting
const pickledOlmAccount =
    'N2v1MkIFGcl0mQpo2OCwSopxPQJ0wnl7oe7PKiT4141AijfdTIhRu+ceXzXKy3Kr00nLqXtRv7kid6hU4a+V0rfJWLL0Y51+3Rp/ORDVnQy+SSeo6Fn4FHcXrxifJEJ0djla5u98fBcJ8BSkhIDmtXRPi5/oJAvpiYn+8zMjFHobOeZUAxYR0VfQ9JzSYBsSovoQ7uFkNks1M4EDUvHtu/BjDjz0C3ioDgrrFdoSrn+GSeF5FGKsNu8OLkQ9Lq5+BrUutK5QSJI19uoZj2sj/OixvIpnun8XxYpXo7cfh9MEtKI8ob7lLM2OpZ8BogU70ORgkwthsPSOtxQGPhx8+y5Sg7B6KGlU';

Future<Client> getClient() async {
  final client = Client('testclient', debug: true, httpClient: FakeMatrixApi());
  client.database = getDatabase();
  await client.checkServer('https://fakeServer.notExisting');
  final resp = await client.api.login(
    type: 'm.login.password',
    user: 'test',
    password: '1234',
    initialDeviceDisplayName: 'Fluffy Matrix Client',
  );
  client.connect(
    newToken: resp.accessToken,
    newUserID: resp.userId,
    newHomeserver: client.api.homeserver,
    newDeviceName: 'Text Matrix Client',
    newDeviceID: resp.deviceId,
    newOlmAccount: pickledOlmAccount,
  );
  await Future.delayed(Duration(milliseconds: 10));
  return client;
}
