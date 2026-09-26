// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:matrix/matrix_api_lite.dart';
import 'package:test/test.dart';

void main() {
  group('UserId extension type', () {
    test('valid user ID accessors', () {
      final user = UserId.fromString('@alice:example.com');
      expect(user.isValid, isTrue);
      expect(user.localpart, 'alice');
      expect(user.serverName, 'example.com');
      expect(user.sigil, '@');
      expect(user.value, '@alice:example.com');
      expect(user.toString(), '@alice:example.com');
    });

    test('malformed user ID does not throw and logs warning', () {
      final malformed = UserId.fromString('not_a_valid_id');
      expect(malformed.isValid, isFalse);
      expect(malformed.value, 'not_a_valid_id');
      expect(malformed.localpart, 'not_a_valid_id');
      expect(malformed.serverName, '');
    });

    test('fromParts constructor', () {
      final user = UserId.fromParts('bob', 'matrix.org');
      expect(user.value, '@bob:matrix.org');
      expect(user.isValid, isTrue);
    });

    test('tryParse returns null on invalid', () {
      expect(UserId.tryParse(null), isNull);
      expect(UserId.tryParse('invalid'), isNull);
      expect(UserId.tryParse('@valid:domain.com'), isNotNull);
    });

    test('jsonEncode works transparently', () {
      const user = UserId('@alice:example.com');
      expect(jsonEncode({'user': user}), '{"user":"@alice:example.com"}');
    });

    test('usable as Map keys', () {
      final map = <UserId, String>{const UserId('@alice:example.com'): 'Alice'};
      expect(map[UserId.fromString('@alice:example.com')], 'Alice');
    });

    test('domain and hasDomain', () {
      final user = UserId.fromString('@alice:example.com');
      expect(user.domain, 'example.com');
      expect(user.hasDomain, isTrue);
      expect(user.toJson(), '@alice:example.com');

      final malformed = UserId.fromString('malformed');
      expect(malformed.domain, isNull);
      expect(malformed.hasDomain, isFalse);
    });
  });

  group('RoomId extension type', () {
    test('valid room ID with domain', () {
      final room = RoomId.fromString('!room:example.com');
      expect(room.isValid, isTrue);
      expect(room.localpart, 'room');
      expect(room.serverName, 'example.com');
      expect(room.sigil, '!');
    });

    test('domainless room ID (room v12)', () {
      final room = RoomId.fromString('!opaque_room_version_12');
      expect(room.isValid, isTrue);
      expect(room.localpart, 'opaque_room_version_12');
      expect(room.serverName, isNull);
    });

    test('malformed room ID does not throw', () {
      final malformed = RoomId.fromString('bad_room');
      expect(malformed.isValid, isFalse);
      expect(malformed.value, 'bad_room');
    });

    test('jsonEncode works transparently', () {
      const room = RoomId('!room:example.com');
      expect(jsonEncode({'room': room}), '{"room":"!room:example.com"}');
    });

    test('tryParse, fromParts, domain, and hasDomain', () {
      final room = RoomId.fromString('!room:example.com');
      expect(room.domain, 'example.com');
      expect(room.hasDomain, isTrue);
      expect(room.toJson(), '!room:example.com');

      final fromPartsWithDomain = RoomId.fromParts('room', 'example.com');
      expect(fromPartsWithDomain.value, '!room:example.com');

      final fromPartsNoDomain = RoomId.fromParts('opaque_v12');
      expect(fromPartsNoDomain.value, '!opaque_v12');
      expect(fromPartsNoDomain.domain, isNull);
      expect(fromPartsNoDomain.hasDomain, isFalse);

      expect(RoomId.tryParse('!room:example.com'), isNotNull);
      expect(RoomId.tryParse('invalid'), isNull);
      expect(RoomId.tryParse(null), isNull);
    });
  });

  group('RoomAlias extension type', () {
    test('valid room alias', () {
      final alias = RoomAlias.fromString('#public:example.org');
      expect(alias.isValid, isTrue);
      expect(alias.localpart, 'public');
      expect(alias.serverName, 'example.org');
      expect(alias.sigil, '#');
    });

    test('fromParts, tryParse, domain, and hasDomain', () {
      final alias = RoomAlias.fromParts('public', 'example.org');
      expect(alias.value, '#public:example.org');
      expect(alias.domain, 'example.org');
      expect(alias.hasDomain, isTrue);
      expect(alias.toJson(), '#public:example.org');

      expect(RoomAlias.tryParse('#public:example.org'), isNotNull);
      expect(RoomAlias.tryParse('invalid'), isNull);
      expect(RoomAlias.tryParse(null), isNull);
    });

    test('malformed alias does not throw', () {
      final malformed = RoomAlias.fromString('invalid_alias');
      expect(malformed.isValid, isFalse);
    });

    test('supports non-BMP Unicode characters and emojis', () {
      final emojiAlias = RoomAlias.fromString('#🎉:example.org');
      expect(emojiAlias.isValid, isTrue);
      expect(emojiAlias.localpart, '🎉');

      final cjkAlias = RoomAlias.fromString('#日本語:example.org');
      expect(cjkAlias.isValid, isTrue);
      expect(cjkAlias.localpart, '日本語');
    });

    test('rejects NUL and unpaired surrogates without throwing', () {
      final nulAlias = RoomAlias.fromString('#foo\u0000bar:example.org');
      expect(nulAlias.isValid, isFalse);

      final surrogateAlias = RoomAlias.fromString('#\uD800:example.org');
      expect(surrogateAlias.isValid, isFalse);
    });
  });

  group('EventId extension type', () {
    test('modern room v3+ opaque event ID', () {
      final event = EventId.fromString(r'$0123456789abcdef');
      expect(event.isValid, isTrue);
      expect(event.localpart, '0123456789abcdef');
      expect(event.serverName, isNull);
      expect(event.sigil, r'$');
      expect(event.domain, isNull);
      expect(event.hasDomain, isFalse);
    });

    test('historical event ID with domain', () {
      final event = EventId.fromString(r'$legacy:example.com');
      expect(event.isValid, isTrue);
      expect(event.localpart, 'legacy');
      expect(event.serverName, 'example.com');
      expect(event.domain, 'example.com');
      expect(event.hasDomain, isTrue);
    });

    test('fromParts, tryParse, and toJson', () {
      final legacy = EventId.fromParts('legacy', 'example.com');
      expect(legacy.value, r'$legacy:example.com');
      expect(legacy.toJson(), r'$legacy:example.com');

      final opaque = EventId.fromParts('opaque_event');
      expect(opaque.value, r'$opaque_event');

      expect(EventId.tryParse(r'$0123456789abcdef'), isNotNull);
      expect(EventId.tryParse('invalid'), isNull);
      expect(EventId.tryParse(null), isNull);
    });

    test('malformed event ID does not throw', () {
      final malformed = EventId.fromString('not_an_event_id');
      expect(malformed.isValid, isFalse);
    });
  });

  group('DeviceId extension type', () {
    test('valid device ID', () {
      final device = DeviceId.fromString('DEVICE123');
      expect(device.isValid, isTrue);
      expect(device.value, 'DEVICE123');
      expect(device.toJson(), 'DEVICE123');

      expect(DeviceId.tryParse('DEVICE123'), isNotNull);
      expect(DeviceId.tryParse(''), isNull);
      expect(DeviceId.tryParse(null), isNull);
    });

    test('device ID with Unicode characters', () {
      final device = DeviceId.fromString('device_📱');
      expect(device.isValid, isTrue);
    });

    test('empty device ID is invalid but does not throw', () {
      final empty = DeviceId.fromString('');
      expect(empty.isValid, isFalse);
    });

    test('rejects NUL byte and unpaired surrogates', () {
      final nulDevice = DeviceId.fromString('dev\u0000ice');
      expect(nulDevice.isValid, isFalse);

      final surrogateDevice = DeviceId.fromString('\uD800');
      expect(surrogateDevice.isValid, isFalse);
    });
  });

  group('isValidServerName validation', () {
    test('validates IPv4, IPv6, domain names, and ports', () {
      expect(isValidServerName('matrix.org'), isTrue);
      expect(isValidServerName('matrix.org:8448'), isTrue);
      expect(isValidServerName('192.168.1.1'), isTrue);
      expect(isValidServerName('192.168.1.1:8008'), isTrue);
      expect(isValidServerName('[::1]'), isTrue);
      expect(isValidServerName('[::1]:8448'), isTrue);

      expect(isValidServerName(''), isFalse);
      expect(isValidServerName('[invalid-ipv6]'), isFalse);
      expect(isValidServerName('999.999.999.999'), isFalse);
      expect(isValidServerName('matrix.org:notaport'), isFalse);
    });
  });
}
