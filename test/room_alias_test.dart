// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:matrix/matrix_api_lite.dart';
import 'package:test/test.dart';

void main() {
  group('RoomAlias', () {
    test('preserves valid aliases through every constructor', () {
      for (final value in [
        '#general:example.org',
        '#:example.org',
        '#Grüße 🦊:EXAMPLE.org:8448',
        '# spaces /?#\n:example.org',
        '#room:localhost',
        '#room:127.0.0.1:8080',
        '#room:[2001:db8::1]:8448',
        '#room:[::ffff:192.0.2.1]',
        '#room:example.org:99999',
      ]) {
        final alias = RoomAlias(value);
        expect(alias.value, value);
        expect(alias.toString(), value);
        expect(RoomAlias.parse(value), alias);
        expect(RoomAlias.tryParse(value), alias);
        expect(RoomAlias.fromParts(alias.localpart, alias.serverName), alias);
      }
    });

    test('rejects malformed aliases without repairing them', () {
      for (final value in [
        '',
        'general:example.org',
        '@general:example.org',
        '#general',
        '#general:',
        '#a\u0000b:example.org',
        '#\ud800:example.org',
        '#\udfff:example.org',
        '#room:https://example.org',
        '#room:exämple.org',
        '#room:example.org/path',
        '#room:example.org\n',
        '#room:example.org:',
        '#room:example.org:123456',
        '#room:example.org:abc',
        '#room:256.1.2.3',
        '#room:[not-ipv6]',
        '#room:[1:2:3]',
        '#room:2001:db8::1',
      ]) {
        expect(() => RoomAlias(value), throwsFormatException, reason: value);
        expect(
          () => RoomAlias.parse(value),
          throwsFormatException,
          reason: value,
        );
        expect(RoomAlias.tryParse(value), isNull, reason: value);
      }
    });

    test('fromParts cannot bypass validation or move the separator', () {
      expect(
        () => RoomAlias.fromParts('a:example.org', '80'),
        throwsFormatException,
      );
      expect(
        () => RoomAlias.fromParts('a\u0000b', 'example.org'),
        throwsFormatException,
      );
      expect(() => RoomAlias.fromParts('general', ''), throwsFormatException);
    });

    test('limits the complete alias to 255 UTF-8 bytes', () {
      final ascii = '#${'a' * 242}:example.org';
      final unicode = '#${'🦊' * 60}ab:example.org';
      expect(utf8.encode(ascii), hasLength(255));
      expect(utf8.encode(unicode), hasLength(255));
      expect(RoomAlias(ascii).value, ascii);
      expect(RoomAlias(unicode).value, unicode);
      expect(
        () => RoomAlias('#${'a' * 243}:example.org'),
        throwsFormatException,
      );
      expect(
        () => RoomAlias('#${'🦊' * 60}abc:example.org'),
        throwsFormatException,
      );
      expect(
        () => RoomAlias.fromParts('🦊' * 61, 'example.org'),
        throwsFormatException,
      );
    });

    test('equality and map lookup preserve type and case', () {
      final alias = RoomAlias('#General:EXAMPLE.org');
      final same = RoomAlias.parse(alias.value);
      expect(alias, same);
      expect(alias.hashCode, same.hashCode);
      expect({alias: 'found'}[same], 'found');
      expect({alias, same}, hasLength(1));
      expect(alias, isNot(RoomAlias('#general:EXAMPLE.org')));
      expect(alias, isNot(RoomAlias('#General:example.org')));
      expect(alias, isNot(alias.value));
      expect(
        RoomAlias('#é:example.org'),
        isNot(RoomAlias('#e\u0301:example.org')),
      );
    });

    test('JSON serialization stays a string', () {
      final alias = RoomAlias('#general:example.org');
      expect(alias.toJson(), alias.value);
      expect(jsonDecode(jsonEncode({'alias': alias})), {'alias': alias.value});
    });
  });
}
