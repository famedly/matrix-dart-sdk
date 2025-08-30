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

import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:matrix/matrix.dart';
import 'fake_database.dart';

const ssssPassphrase = 'nae7ahDiequ7ohniufah3ieS2je1thohX4xeeka7aixohsho9O';
const ssssKey = 'EsT9 RzbW VhPW yqNp cC7j ViiW 5TZB LuY4 ryyv 9guN Ysmr WDPH';

// key @test:fakeServer.notExisting
const pickledOlmAccount =
    'huxcPifHlyiQsX7cZeMMITbka3hLeUT3ss6DLL6dV7knaD4wgAYK6gcWknkixnX8C5KMIyxzytxiNqAOhDFRE5NsET8hr2dQ8OvXX7M95eQ7/3dPi7FkPUIbvneTSGgJYNDxJdHsDJ8OBHZ3BoqUJFDbTzFfVJjEzN4G9XQwPDafZ2p5WyerOK8Twj/rvk5N+ERmkt1XgVLQl66we/BO1ugTeM3YpDHm5lTzFUitJGTIuuONsKG9mmzdAmVUJ9YIrSxwmOBdegbGA+LAl5acg5VOol3KxRgZUMJQRQ58zpBAs72oauHizv1QVoQ7uIUiCUeb9lym+TEjmApvhru/1CPHU90K5jHNZ57wb/4V9VsqBWuoNibzDWG35YTFLcx0o+1lrCIjm1QjuC0777G+L1HNw5wnppV3z/k0YujjuPS3wvOA30TjHg';

Future? vodInit;

/// only use `path` if you explicitly if you need a db on path instead of in mem
Future<Client> getClient({
  Duration sendTimelineEventTimeout = const Duration(minutes: 1),
  String? databasePath,
}) async {
  try {
    vodInit ??= vod.init(
      wasmPath: './pkg/',
      libraryPath: './rust/target/debug/',
    );
    await vodInit;
  } catch (_) {
    Logs().d('Encryption via Vodozemac not enabled');
  }
  final client = Client(
    logLevel: Level.verbose,
    'testclient',
    httpClient: FakeMatrixApi(),
    database: await getDatabase(databasePath: databasePath),
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
    database: await getDatabase(),
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
