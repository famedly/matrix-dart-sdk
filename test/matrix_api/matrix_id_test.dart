// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite.dart';
import 'package:test/test.dart';

void main() {
  group('MatrixId polymorphic parsing', () {
    test('parses UserId from @ sigil', () {
      final id = MatrixId.parse('@alice:example.com');
      expect(id, isA<UserId>());
      expect(id.sigil, '@');
      expect(id.localpart, 'alice');
      expect(id.serverName, 'example.com');
      expect(id.toString(), '@alice:example.com');
      expect(id.toJson(), '@alice:example.com');
    });

    test('parses RoomId from ! sigil with domain', () {
      final id = MatrixId.parse('!room:example.com');
      expect(id, isA<RoomId>());
      expect(id.sigil, '!');
      expect(id.localpart, 'room');
      expect(id.serverName, 'example.com');
    });

    test('parses Room Version 12 domainless RoomId from ! sigil', () {
      final id = MatrixId.parse('!opaque_room_version_12_hash');
      expect(id, isA<RoomId>());
      expect(id.sigil, '!');
      expect(id.localpart, 'opaque_room_version_12_hash');
      expect(id.serverName, isNull);
    });

    test('parses RoomAlias from # sigil', () {
      final id = MatrixId.parse('#alias:example.com');
      expect(id, isA<RoomAlias>());
      expect(id.sigil, '#');
      expect(id.localpart, 'alias');
      expect(id.serverName, 'example.com');
    });

    test('parses EventId from \$ sigil (with domain)', () {
      final id = MatrixId.parse(r'$event:example.com');
      expect(id, isA<EventId>());
      expect(id.sigil, r'$');
      expect(id.localpart, 'event');
      expect(id.serverName, 'example.com');
    });

    test('parses modern room v3+ EventId from \$ sigil (without domain)', () {
      final id = MatrixId.parse(r'$opaque_base64_hash_value');
      expect(id, isA<EventId>());
      expect(id.sigil, r'$');
      expect(id.localpart, 'opaque_base64_hash_value');
      expect(id.serverName, isNull);
    });

    test('supports exhaustive switch pattern matching', () {
      String describe(MatrixId id) => switch (id) {
        final UserId u => 'user:${u.localpart}@${u.serverName}',
        final RoomId r => 'room:${r.localpart}@${r.serverName}',
        final RoomAlias a => 'alias:${a.localpart}@${a.serverName}',
        final EventId e => 'event:${e.localpart}',
      };

      expect(
        describe(MatrixId.parse('@bob:matrix.org')),
        'user:bob@matrix.org',
      );
      expect(
        describe(MatrixId.parse('!dev:matrix.org')),
        'room:dev@matrix.org',
      );
      expect(
        describe(MatrixId.parse('#public:matrix.org')),
        'alias:public@matrix.org',
      );
      expect(describe(MatrixId.parse(r'$xyz123')), 'event:xyz123');
    });

    test('tryParse returns null on invalid sigil or malformed input', () {
      expect(MatrixId.tryParse(''), isNull);
      expect(MatrixId.tryParse('invalid'), isNull);
      expect(MatrixId.tryParse('+group:example.com'), isNull);
      expect(MatrixId.tryParse('@alice_no_server'), isNull);
    });
  });

  group('UserId', () {
    test('constructors and parts', () {
      final u1 = UserId('@alice:example.com');
      final u2 = UserId.parse('@alice:example.com');
      final u3 = UserId.fromParts('alice', 'example.com');

      expect(u1, equals(u2));
      expect(u1, equals(u3));
      expect(u1.hashCode, equals(u2.hashCode));
      expect(u1.localpart, 'alice');
      expect(u1.serverName, 'example.com');
    });

    test('accepts historical user IDs', () {
      // Historical IDs per Matrix spec may have empty or arbitrary localparts
      final emptyLocalpart = UserId('@:example.com');
      expect(emptyLocalpart.localpart, '');
      expect(emptyLocalpart.serverName, 'example.com');

      final unicode = UserId('@üser:example.com');
      expect(unicode.localpart, 'üser');
    });

    test('validates server names (IPv4, IPv6, ports)', () {
      expect(() => UserId('@alice:192.168.1.1'), returnsNormally);
      expect(() => UserId('@alice:192.168.1.1:8448'), returnsNormally);
      expect(() => UserId('@alice:[2001:db8::1]'), returnsNormally);
      expect(() => UserId('@alice:[2001:db8::1]:8448'), returnsNormally);
    });

    test('throws on invalid user IDs', () {
      expect(() => UserId(''), throwsFormatException);
      expect(() => UserId('alice:example.com'), throwsFormatException);
      expect(() => UserId('@alice'), throwsFormatException);
      expect(() => UserId('@alice:'), throwsFormatException);
      expect(() => UserId('@alice:invalid server'), throwsFormatException);
      expect(() => UserId('@al\x00ice:example.com'), throwsFormatException);
      expect(
        () => UserId.fromParts('al:ice', 'example.com'),
        throwsFormatException,
      );
    });

    test('tryParse returns null on error', () {
      expect(UserId.tryParse('@alice'), isNull);
      expect(UserId.tryParse('@alice:valid.org'), isNotNull);
    });
  });

  group('RoomId', () {
    test('constructors and parts with domain', () {
      final r1 = RoomId('!room:example.com');
      final r2 = RoomId.parse('!room:example.com');
      final r3 = RoomId.fromParts('room', 'example.com');

      expect(r1, equals(r2));
      expect(r1, equals(r3));
      expect(r1.localpart, 'room');
      expect(r1.serverName, 'example.com');
    });

    test('supports Room Version 12 domainless room IDs', () {
      final r1 = RoomId('!opaque_room_version_12_hash');
      final r2 = RoomId.fromParts('opaque_room_version_12_hash');

      expect(r1, equals(r2));
      expect(r1.localpart, 'opaque_room_version_12_hash');
      expect(r1.serverName, isNull);
    });

    test('throws on invalid room IDs', () {
      expect(() => RoomId(''), throwsFormatException);
      expect(() => RoomId('!'), throwsFormatException);
      expect(() => RoomId('@room:example.com'), throwsFormatException);
      expect(() => RoomId('!room:invalid port:abc'), throwsFormatException);
      expect(() => RoomId.fromParts('room:example.org'), throwsFormatException);
    });
  });

  group('RoomAlias', () {
    test('constructors and parts', () {
      final a1 = RoomAlias('#alias:example.com');
      final a2 = RoomAlias.parse('#alias:example.com');
      final a3 = RoomAlias.fromParts('alias', 'example.com');

      expect(a1, equals(a2));
      expect(a1, equals(a3));
      expect(a1.localpart, 'alias');
      expect(a1.serverName, 'example.com');
    });

    test('throws on invalid room aliases', () {
      expect(() => RoomAlias(''), throwsFormatException);
      expect(() => RoomAlias('#alias'), throwsFormatException);
      expect(() => RoomAlias('!alias:example.com'), throwsFormatException);
    });
  });

  group('EventId', () {
    test('legacy format with domain', () {
      final e1 = EventId(r'$event:example.com');
      final e2 = EventId.fromParts('event', 'example.com');

      expect(e1, equals(e2));
      expect(e1.localpart, 'event');
      expect(e1.serverName, 'example.com');
    });

    test('modern room v3+ format without domain', () {
      final e1 = EventId(r'$0123456789abcdefABCDEF-_');
      final e2 = EventId.fromParts('0123456789abcdefABCDEF-_');

      expect(e1, equals(e2));
      expect(e1.localpart, '0123456789abcdefABCDEF-_');
      expect(e1.serverName, isNull);
    });

    test('fromParts rejects colons when serverName is omitted', () {
      expect(
        () => EventId.fromParts('event:example.org'),
        throwsFormatException,
      );
    });

    test('throws on invalid event IDs', () {
      expect(() => EventId(''), throwsFormatException);
      expect(() => EventId(r'$'), throwsFormatException);
      expect(() => EventId('event:example.com'), throwsFormatException);
      expect(
        () => EventId(
          r'$event'
          '\x00'
          ':example.com',
        ),
        throwsFormatException,
      );
    });
  });

  group('Length and byte boundary validation', () {
    test('rejects NUL characters', () {
      expect(() => UserId('@al\x00ice:example.com'), throwsFormatException);
      expect(() => RoomId('!ro\x00om:example.com'), throwsFormatException);
      expect(() => RoomId('!opaque\x00hash'), throwsFormatException);
      expect(() => RoomAlias('#al\x00ias:example.com'), throwsFormatException);
      expect(
        () => EventId(
          r'$ev'
          '\x00'
          'ent:example.com',
        ),
        throwsFormatException,
      );
      expect(
        () => EventId(
          r'$opaque'
          '\x00'
          'hash',
        ),
        throwsFormatException,
      );
    });

    test('accepts exactly 255 UTF-8 bytes and rejects 256 bytes', () {
      // 254 'a's + '@' = 255 bytes
      final exact255 = '@${'a' * 242}:example.com';
      expect(exact255.length, 255);
      expect(() => UserId(exact255), returnsNormally);

      final tooLong256 = '@${'a' * 243}:example.com';
      expect(tooLong256.length, 256);
      expect(() => UserId(tooLong256), throwsFormatException);

      // Multi-byte Unicode length check (Euro symbol is 3 bytes in UTF-8)
      // '@' (1) + ':' (1) + 'example.com' (11) = 13 bytes overhead
      // 255 - 13 = 242 bytes. 80 * 3 = 240 bytes + 2 'a's = 242 bytes
      final unicode255Bytes = '@${'€' * 80}aa:example.com';
      expect(() => UserId(unicode255Bytes), returnsNormally);

      final unicode256Bytes =
          '@${'€' * 81}:example.com'; // 243 + 13 = 256 bytes
      expect(() => UserId(unicode256Bytes), throwsFormatException);
    });

    test('rejects unpaired surrogates', () {
      expect(() => UserId('@\uD800:example.com'), throwsFormatException);
    });
  });

  group('Cross-type equality', () {
    test('different types with identical string value are not equal', () {
      final user = UserId('@test:example.com');
      expect((user as Object) == '@test:example.com', isFalse);
    });
  });
}
