import 'package:test/test.dart';
import 'package:matrix/matrix_api_lite/model/matrix_id.dart';

void main() {
  group('UserId', () {
    test('parses and extracts components', () {
      final userId = UserId('@alice:example.com');
      expect(userId.localpart, 'alice');
      expect(userId.domain, 'example.com');
    });

    test('creates from localpart and domain', () {
      final userId = UserId.from('bob', 'matrix.org');
      expect(userId.localpart, 'bob');
    });

    test('tryParse returns null for invalid input', () {
      expect(UserId.tryParse('not-a-user-id'), isNull);
      expect(UserId.tryParse('@alice'), isNull);
    });

    test('rejects missing domain', () {
      expect(() => UserId('@alice'), throwsException);
    });

    test('rejects wrong sigil', () {
      expect(() => UserId('!alice:example.com'), throwsException);
    });

    test('has correct sigil constant', () {
      expect(UserId.sigil, '@');
    });
  });

  group('RoomId', () {
    test('parses and extracts components', () {
      final roomId = RoomId('!abc123:example.com');
      expect(roomId.localpart, 'abc123');
      expect(roomId.domain, 'example.com');
    });

    test('allows optional domain', () {
      final roomId = RoomId.from('ghi789');
      expect(roomId.domain, isNull);
    });

    test('tryParse returns null for invalid sigil', () {
      expect(RoomId.tryParse('@alice:example.com'), isNull);
    });

    test('rejects wrong sigil', () {
      expect(() => RoomId('@room:example.com'), throwsException);
    });

    test('has correct sigil constant', () {
      expect(RoomId.sigil, '!');
    });
  });

  group('RoomAlias', () {
    test('parses and extracts components', () {
      final alias = RoomAlias('#general:example.com');
      expect(alias.localpart, 'general');
      expect(alias.domain, 'example.com');
    });

    test('requires domain', () {
      expect(() => RoomAlias('#support'), throwsException);
    });

    test('tryParse returns null for missing domain', () {
      expect(RoomAlias.tryParse('#general'), isNull);
    });

    test('rejects wrong sigil', () {
      expect(() => RoomAlias('@admin:example.com'), throwsException);
    });

    test('has correct sigil constant', () {
      expect(RoomAlias.sigil, '#');
    });
  });

  group('EventId', () {
    test('parses and extracts components', () {
      final eventId = EventId('\$abc123:example.com');
      expect(eventId.localpart, 'abc123');
      expect(eventId.domain, 'example.com');
    });

    test('allows optional domain', () {
      final eventId = EventId.from('ghi789');
      expect(eventId.domain, isNull);
    });

    test('tryParse returns null for invalid sigil', () {
      expect(EventId.tryParse('@alice:example.com'), isNull);
    });

    test('rejects wrong sigil', () {
      expect(() => EventId('@event:example.com'), throwsException);
    });

    test('has correct sigil constant', () {
      expect(EventId.sigil, '\$');
    });
  });

  group('Validation', () {
    test('rejects whitespace', () {
      expect(() => UserId(' @alice:example.com'), throwsException);
      expect(() => RoomAlias('#general:example.com '), throwsException);
    });

    test('rejects empty localpart', () {
      expect(() => UserId('@:example.com'), throwsException);
    });

    test('rejects NUL character', () {
      expect(() => UserId('@alice\u0000:example.com'), throwsException);
    });

    test('rejects strings exceeding 255 bytes', () {
      final longLocalpart = 'a' * 250;
      expect(
        () => UserId('@$longLocalpart:example.com'),
        throwsException,
      );
    });
  });

  group('Round-trip consistency', () {
    test('from() matches direct constructor', () {
      final userId1 = UserId.from('alice', 'example.com');
      final userId2 = UserId('@alice:example.com');
      expect(userId1.localpart, userId2.localpart);
      expect(userId1.domain, userId2.domain);
    });
  });

  group('Special characters', () {
    test('handles dots and plus in localpart', () {
      final userId = UserId.from('user.name+test', 'example.com');
      expect(userId.localpart, 'user.name+test');
    });

    test('handles hyphens and underscores', () {
      final alias = RoomAlias.from('my-awesome_room', 'example.com');
      expect(alias.localpart, 'my-awesome_room');
    });

    test('handles domain with port', () {
      final userId = UserId('@alice:example.com:8008');
      expect(userId.domain, 'example.com:8008');
    });
  });
}
