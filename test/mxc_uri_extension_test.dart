/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020 Famedly GmbH
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

import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import 'fake_database.dart';

void main() {
  /// All Tests related to the MxContent
  group('MxContent', () {
    Logs().level = Level.error;

    late Client client;
    setUp(() async {
      client = Client(
        'testclient',
        httpClient: FakeMatrixApi(),
        database: await getDatabase(),
      );
    });

    tearDown(() async {
      await client.dispose();
    });

    test('Formatting', () async {
      await client.checkHomeserver(
        Uri.parse('https://fakeserver.notexisting'),
        checkWellKnown: false,
      );
      const mxc = 'mxc://exampleserver.abc/abcdefghijklmn';
      final content = Uri.parse(mxc);
      expect(content.isScheme('mxc'), true);

      expect(
        (await content.getDownloadUri(client)).toString(),
        '${client.homeserver}/_matrix/client/v1/media/download/exampleserver.abc/abcdefghijklmn',
      );
      expect(
        (await content.getThumbnailUri(client, width: 50, height: 50))
            .toString(),
        '${client.homeserver}/_matrix/client/v1/media/thumbnail/exampleserver.abc/abcdefghijklmn?width=50&height=50&method=crop&animated=false',
      );
      expect(
        (await content.getThumbnailUri(
          client,
          width: 50,
          height: 50,
          method: ThumbnailMethod.scale,
          animated: true,
        ))
            .toString(),
        '${client.homeserver}/_matrix/client/v1/media/thumbnail/exampleserver.abc/abcdefghijklmn?width=50&height=50&method=scale&animated=true',
      );
    });
    test('other port', () async {
      await client.checkHomeserver(
        Uri.parse('https://fakeserver.notexisting'),
        checkWellKnown: false,
      );
      client.homeserver = Uri.parse('https://fakeserver.notexisting:1337');
      const mxc = 'mxc://exampleserver.abc/abcdefghijklmn';
      final content = Uri.parse(mxc);
      expect(content.isScheme('mxc'), true);

      expect(
        (await content.getDownloadUri(client)).toString(),
        '${client.homeserver}/_matrix/client/v1/media/download/exampleserver.abc/abcdefghijklmn',
      );
      expect(
        (await content.getThumbnailUri(client, width: 50, height: 50))
            .toString(),
        '${client.homeserver}/_matrix/client/v1/media/thumbnail/exampleserver.abc/abcdefghijklmn?width=50&height=50&method=crop&animated=false',
      );
      expect(
        (await content.getThumbnailUri(
          client,
          width: 50,
          height: 50,
          method: ThumbnailMethod.scale,
          animated: true,
        ))
            .toString(),
        'https://fakeserver.notexisting:1337/_matrix/client/v1/media/thumbnail/exampleserver.abc/abcdefghijklmn?width=50&height=50&method=scale&animated=true',
      );
    });
    test('other remote port', () async {
      await client.checkHomeserver(
        Uri.parse('https://fakeserver.notexisting'),
        checkWellKnown: false,
      );
      const mxc = 'mxc://exampleserver.abc:1234/abcdefghijklmn';
      final content = Uri.parse(mxc);
      expect(content.isScheme('mxc'), true);

      expect(
        (await content.getDownloadUri(client)).toString(),
        '${client.homeserver}/_matrix/client/v1/media/download/exampleserver.abc:1234/abcdefghijklmn',
      );
      expect(
        (await content.getThumbnailUri(client, width: 50, height: 50))
            .toString(),
        '${client.homeserver}/_matrix/client/v1/media/thumbnail/exampleserver.abc:1234/abcdefghijklmn?width=50&height=50&method=crop&animated=false',
      );
    });
    test('Wrong scheme throw exception', () async {
      await client.checkHomeserver(
        Uri.parse('https://fakeserver.notexisting'),
        checkWellKnown: false,
      );
      final mxc = Uri.parse('https://wrong-scheme.com');
      expect((await mxc.getDownloadUri(client)).toString(), '');
      expect((await mxc.getThumbnailUri(client)).toString(), '');
    });

    test('auth media fallback', () async {
      await client.checkHomeserver(
        Uri.parse('https://fakeserverpriortoauthmedia.notexisting'),
        checkWellKnown: false,
      );

      expect(await client.authenticatedMediaSupported(), false);
      const mxc = 'mxc://exampleserver.abc:1234/abcdefghijklmn';
      final content = Uri.parse(mxc);
      expect(content.isScheme('mxc'), true);

      expect(
        (await content.getDownloadUri(client)).toString(),
        '${client.homeserver}/_matrix/media/v3/download/exampleserver.abc:1234/abcdefghijklmn',
      );
      expect(
        (await content.getThumbnailUri(client, width: 50, height: 50))
            .toString(),
        '${client.homeserver}/_matrix/media/v3/thumbnail/exampleserver.abc:1234/abcdefghijklmn?width=50&height=50&method=crop&animated=false',
      );
    });
  });
}
