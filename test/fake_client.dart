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

const SSSS_PASSPHRASE = 'nae7ahDiequ7ohniufah3ieS2je1thohX4xeeka7aixohsho9O';
const SSSS_KEY = 'EsT9 RzbW VhPW yqNp cC7j ViiW 5TZB LuY4 ryyv 9guN Ysmr WDPH';

// key @test:fakeServer.notExisting
const pickledOlmAccount =
    'N2v1MkIFGcl0mQpo2OCwSopxPQJ0wnl7oe7PKiT4141AijfdTIhRu+ceXzXKy3Kr00nLqXtRv7kid6hU4a+V0rfJWLL0Y51+3Rp/ORDVnQy+SSeo6Fn4FHcXrxifJEJ0djla5u98fBcJ8BSkhIDmtXRPi5/oJAvpiYn+8zMjFHobOeZUAxYR0VfQ9JzSYBsSovoQ7uFkNks1M4EDUvHtuyg3RxViwdNxs3718fyAqQ/VSwbXsY0Nl+qQbF+nlVGHenGqk5SuNl1P6e1PzZxcR0IfXA94Xij1Ob5gDv5YH4UCn9wRMG0abZsQP0YzpDM0FLaHSCyo9i5JD/vMlhH+nZWrgAzPPCTNGYewNV8/h3c+VyJh8ZTx/fVi6Yq46Fv+27Ga2ETRZ3Qn+Oyx6dLBjnBZ9iUvIhqpe2XqaGA1PopOz8iDnaZitw';

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
