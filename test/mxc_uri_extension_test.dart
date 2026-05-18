// SPDX-FileCopyrightText: 2019, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import 'fake_database.dart';

void main() {
  /// All Tests related to the MxContent
  group('MxContent', () {
    Logs().level = Level.error;
    test('Formatting', () async {
      final client = Client(
        'testclient',
        httpClient: FakeMatrixApi(),
        database: await getDatabase(),
      );
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
      final client = Client(
        'testclient',
        httpClient: FakeMatrixApi(),
        database: await getDatabase(),
      );
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
      final client = Client(
        'testclient',
        httpClient: FakeMatrixApi(),
        database: await getDatabase(),
      );
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
      final client = Client(
        'testclient',
        httpClient: FakeMatrixApi(),
        database: await getDatabase(),
      );
      await client.checkHomeserver(
        Uri.parse('https://fakeserver.notexisting'),
        checkWellKnown: false,
      );
      final mxc = Uri.parse('https://wrong-scheme.com');
      expect((await mxc.getDownloadUri(client)).toString(), '');
      expect((await mxc.getThumbnailUri(client)).toString(), '');
    });

    test('auth media fallback', () async {
      final client = Client(
        'testclient',
        httpClient: FakeMatrixApi(),
        database: await getDatabase(),
      );
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
