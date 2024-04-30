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

void main() {
  /// All Tests related to the MxContent
  group('MxContent', () {
    Logs().level = Level.error;
    test('Formatting', () async {
      final client = Client('testclient', httpClient: FakeMatrixApi());
      await client.checkHomeserver(Uri.parse('https://fakeserver.notexisting'),
          checkWellKnown: false);
      final mxc = 'mxc://exampleserver.abc/abcdefghijklmn';
      final content = Uri.parse(mxc);
      expect(content.isScheme('mxc'), true);

      expect(content.getDownloadLink(client).toString(),
          '${client.homeserver.toString()}/_matrix/media/v3/download/exampleserver.abc/abcdefghijklmn');
      expect(content.getThumbnail(client, width: 50, height: 50).toString(),
          '${client.homeserver.toString()}/_matrix/media/v3/thumbnail/exampleserver.abc/abcdefghijklmn?width=50&height=50&method=crop&animated=false');
      expect(
          content
              .getThumbnail(client,
                  width: 50,
                  height: 50,
                  method: ThumbnailMethod.scale,
                  animated: true)
              .toString(),
          '${client.homeserver.toString()}/_matrix/media/v3/thumbnail/exampleserver.abc/abcdefghijklmn?width=50&height=50&method=scale&animated=true');
    });
    test('other port', () async {
      final client = Client('testclient', httpClient: FakeMatrixApi());
      await client.checkHomeserver(Uri.parse('https://fakeserver.notexisting'),
          checkWellKnown: false);
      client.homeserver = Uri.parse('https://fakeserver.notexisting:1337');
      final mxc = 'mxc://exampleserver.abc/abcdefghijklmn';
      final content = Uri.parse(mxc);
      expect(content.isScheme('mxc'), true);

      expect(content.getDownloadLink(client).toString(),
          '${client.homeserver.toString()}/_matrix/media/v3/download/exampleserver.abc/abcdefghijklmn');
      expect(content.getThumbnail(client, width: 50, height: 50).toString(),
          '${client.homeserver.toString()}/_matrix/media/v3/thumbnail/exampleserver.abc/abcdefghijklmn?width=50&height=50&method=crop&animated=false');
      expect(
          content
              .getThumbnail(client,
                  width: 50,
                  height: 50,
                  method: ThumbnailMethod.scale,
                  animated: true)
              .toString(),
          'https://fakeserver.notexisting:1337/_matrix/media/v3/thumbnail/exampleserver.abc/abcdefghijklmn?width=50&height=50&method=scale&animated=true');
    });
    test('other remote port', () async {
      final client = Client('testclient', httpClient: FakeMatrixApi());
      await client.checkHomeserver(Uri.parse('https://fakeserver.notexisting'),
          checkWellKnown: false);
      final mxc = 'mxc://exampleserver.abc:1234/abcdefghijklmn';
      final content = Uri.parse(mxc);
      expect(content.isScheme('mxc'), true);

      expect(content.getDownloadLink(client).toString(),
          '${client.homeserver.toString()}/_matrix/media/v3/download/exampleserver.abc:1234/abcdefghijklmn');
      expect(content.getThumbnail(client, width: 50, height: 50).toString(),
          '${client.homeserver.toString()}/_matrix/media/v3/thumbnail/exampleserver.abc:1234/abcdefghijklmn?width=50&height=50&method=crop&animated=false');
    });
  });
}
