// SPDX-FileCopyrightText: 2019, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/src/utils/matrix_id_string_extension.dart';
import 'package:test/test.dart';

void main() {
  /// All Tests related to the ChatTime
  group('Matrix ID String Extension', () {
    test('Matrix ID String Extension', () async {
      const mxId = '@test:example.com';
      expect(mxId.isValidMatrixId, true);
      expect('#test:example.com'.isValidMatrixId, true);
      expect('!test:example.com'.isValidMatrixId, true);
      expect('+test:example.com'.isValidMatrixId, true);
      expect('\$test:example.com'.isValidMatrixId, true);
      expect('\$testevent'.isValidMatrixId, true);
      expect('test:example.com'.isValidMatrixId, false);
      expect('@testexample.com'.isValidMatrixId, false);
      expect('@:example.com'.isValidMatrixId, true);
      expect('@test:'.isValidMatrixId, false);
      expect(mxId.sigil, '@');
      expect('#test:example.com'.sigil, '#');
      expect('!test:example.com'.sigil, '!');
      expect('+test:example.com'.sigil, '+');
      expect('\$test:example.com'.sigil, '\$');
      expect(mxId.localpart, 'test');
      expect(mxId.domain, 'example.com');
      expect(mxId.equals('@Test:example.com'), true);
      expect(mxId.equals('@test:example.org'), false);
      expect('@user:domain:8448'.localpart, 'user');
      expect('@user:domain:8448'.domain, 'domain:8448');
    });
    test('isValidMatrixIdStrict', () {
      // Identifiers which are valid in the strict variant.
      const validIds = [
        '@test:example.com',
        '@test.user:example.com',
        '@test-user_1=2/3+4:example.com',
        '#test:example.com',
        '#🦊:example.com',
        '+test:example.com',
        '!test:example.com',
        '!opaqueRoomIdWithoutDomain',
        '\$test:example.com',
        '\$testevent',
        // Various legal server names.
        '@a:matrix.org:8888',
        '@a:1.2.3.4',
        '@a:1.2.3.4:1234',
        '@a:[1234:5678::abcd]',
        '@a:[1234:5678::abcd]:5678',
      ];
      for (final id in validIds) {
        expect(id.isValidMatrixIdStrict, true, reason: '$id should be valid');
      }

      // Identifiers which are rejected by the strict variant.
      const invalidIds = [
        // The papercut from the original issue.
        '@@test:fakeServer.notExisting',
        // Missing sigil.
        'test:example.com',
        // Missing domain separator.
        '@testexample.com',
        // Empty localpart / domain.
        '@:example.com',
        '@test:',
        '#:example.com',
        '+:example.com',
        '!:example.com',
        '!',
        '\$',
        // Illegal characters in a user localpart (historical-only chars).
        '@TestUser:example.com',
        '@test user:example.com',
        '@test^:example.com',
        // Illegal server names.
        '@test:exa mple.com',
        '@test:example.com:notaport',
        '@test:example.com:1234567',
        '@test:[notipv6]:8448',
        // Trailing junk after a valid looking id.
        '@test:example.com ',
        '@userid:domain:',
        // Not a matrix id at all.
        '',
        'hello world',
      ];
      for (final id in invalidIds) {
        expect(
          id.isValidMatrixIdStrict,
          false,
          reason: '$id should be invalid',
        );
      }

      // The lenient validator stays untouched and still accepts the papercut.
      expect('@@test:fakeServer.notExisting'.isValidMatrixId, true);
      expect('@:example.com'.isValidMatrixId, true);
    });
    test('parseIdentifierIntoParts', () {
      var res = '#alias:beep'.parseIdentifierIntoParts()!;
      expect(res.primaryIdentifier, '#alias:beep');
      expect(res.secondaryIdentifier, null);
      expect(res.queryString, null);
      expect('blha'.parseIdentifierIntoParts(), null);
      res = '#alias:beep/\$event'.parseIdentifierIntoParts()!;
      expect(res.primaryIdentifier, '#alias:beep');
      expect(res.secondaryIdentifier, '\$event');
      expect(res.queryString, null);
      res = '#alias:beep?blubb'.parseIdentifierIntoParts()!;
      expect(res.primaryIdentifier, '#alias:beep');
      expect(res.secondaryIdentifier, null);
      expect(res.queryString, 'blubb');
      res = '#alias:beep/\$event?blubb'.parseIdentifierIntoParts()!;
      expect(res.primaryIdentifier, '#alias:beep');
      expect(res.secondaryIdentifier, '\$event');
      expect(res.queryString, 'blubb');
      res = '#/\$?:beep/\$event?blubb?b'.parseIdentifierIntoParts()!;
      expect(res.primaryIdentifier, '#/\$?:beep');
      expect(res.secondaryIdentifier, '\$event');
      expect(res.queryString, 'blubb?b');

      res = 'https://matrix.to/#/#alias:beep'.parseIdentifierIntoParts()!;
      expect(res.primaryIdentifier, '#alias:beep');
      expect(res.secondaryIdentifier, null);
      expect(res.queryString, null);
      res = 'https://matrix.to/#/#🦊:beep'.parseIdentifierIntoParts()!;
      expect(res.primaryIdentifier, '#🦊:beep');
      expect(res.secondaryIdentifier, null);
      expect(res.queryString, null);
      res = 'https://matrix.to/#/%23alias%3abeep'.parseIdentifierIntoParts()!;
      expect(res.primaryIdentifier, '#alias:beep');
      expect(res.secondaryIdentifier, null);
      expect(res.queryString, null);
      res = 'https://matrix.to/#/%23alias%3abeep?boop%F0%9F%A7%A1%F0%9F%A6%8A'
          .parseIdentifierIntoParts()!;
      expect(res.primaryIdentifier, '#alias:beep');
      expect(res.secondaryIdentifier, null);
      expect(res.queryString, 'boop%F0%9F%A7%A1%F0%9F%A6%8A');

      res = 'https://matrix.to/#/#alias:beep?via=fox.com&via=fox.org'
          .parseIdentifierIntoParts()!;
      expect(res.via, <String>{'fox.com', 'fox.org'});

      res = 'matrix:u/her:example.org'.parseIdentifierIntoParts()!;
      expect(res.primaryIdentifier, '@her:example.org');
      expect(res.secondaryIdentifier, null);
      expect('matrix:u/bad'.parseIdentifierIntoParts(), null);
      res = 'matrix:roomid/rid:example.org'.parseIdentifierIntoParts()!;
      expect(res.primaryIdentifier, '!rid:example.org');
      expect(res.secondaryIdentifier, null);
      expect(res.action, null);
      res = 'matrix:r/us:example.org?action=chat'.parseIdentifierIntoParts()!;
      expect(res.primaryIdentifier, '#us:example.org');
      expect(res.secondaryIdentifier, null);
      expect(res.action, 'chat');
      res = 'matrix:r/us:example.org/e/lol823y4bcp3qo4'
          .parseIdentifierIntoParts()!;
      expect(res.primaryIdentifier, '#us:example.org');
      expect(res.secondaryIdentifier, '\$lol823y4bcp3qo4');
      res = 'matrix:roomid/rid:example.org?via=fox.com&via=fox.org'
          .parseIdentifierIntoParts()!;
      expect(res.primaryIdentifier, '!rid:example.org');
      expect(res.secondaryIdentifier, null);
      expect(res.via, <String>{'fox.com', 'fox.org'});
      expect('matrix:beep/boop:example.org'.parseIdentifierIntoParts(), null);
      expect('matrix:boop'.parseIdentifierIntoParts(), null);
    });
  });
}
