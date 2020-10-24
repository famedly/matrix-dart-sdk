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

import 'dart:convert';

import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/src/utils/logs.dart';
import 'package:test/test.dart';
import 'package:olm/olm.dart' as olm;

import '../fake_client.dart';

void main() {
  group('Key Manager', () {
    var olmEnabled = true;
    try {
      olm.init();
      olm.Account();
    } catch (_) {
      olmEnabled = false;
      Logs.warning('[LibOlm] Failed to load LibOlm: ' + _.toString());
    }
    Logs.success('[LibOlm] Enabled: $olmEnabled');

    if (!olmEnabled) return;

    Client client;

    test('setupClient', () async {
      client = await getClient();
    });

    test('handle new m.room_key', () async {
      final validSessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
      final validSenderKey = 'JBG7ZaPn54OBC7TuIEiylW3BZ+7WcGQhFBPB9pogbAg';
      final sessionKey =
          'AgAAAAAQcQ6XrFJk6Prm8FikZDqfry/NbDz8Xw7T6e+/9Yf/q3YHIPEQlzv7IZMNcYb51ifkRzFejVvtphS7wwG2FaXIp4XS2obla14iKISR0X74ugB2vyb1AydIHE/zbBQ1ic5s3kgjMFlWpu/S3FQCnCrv+DPFGEt3ERGWxIl3Bl5X53IjPyVkz65oljz2TZESwz0GH/QFvyOOm8ci0q/gceaF3S7Dmafg3dwTKYwcA5xkcc+BLyrLRzB6Hn+oMAqSNSscnm4mTeT5zYibIhrzqyUTMWr32spFtI9dNR/RFSzfCw';

      client.encryption.keyManager.clearInboundGroupSessions();
      var event = ToDeviceEvent(
          sender: '@alice:example.com',
          type: 'm.room_key',
          content: {
            'algorithm': 'm.megolm.v1.aes-sha2',
            'room_id': '!726s6s6q:example.com',
            'session_id': validSessionId,
            'session_key': sessionKey,
          },
          encryptedContent: {
            'sender_key': validSenderKey,
          });
      await client.encryption.keyManager.handleToDeviceEvent(event);
      expect(
          client.encryption.keyManager.getInboundGroupSession(
                  '!726s6s6q:example.com', validSessionId, validSenderKey) !=
              null,
          true);

      // now test a few invalid scenarios

      // not encrypted
      client.encryption.keyManager.clearInboundGroupSessions();
      event = ToDeviceEvent(
          sender: '@alice:example.com',
          type: 'm.room_key',
          content: {
            'algorithm': 'm.megolm.v1.aes-sha2',
            'room_id': '!726s6s6q:example.com',
            'session_id': validSessionId,
            'session_key': sessionKey,
          });
      await client.encryption.keyManager.handleToDeviceEvent(event);
      expect(
          client.encryption.keyManager.getInboundGroupSession(
                  '!726s6s6q:example.com', validSessionId, validSenderKey) !=
              null,
          false);
    });

    test('outbound group session', () async {
      final roomId = '!726s6s6q:example.com';
      expect(
          client.encryption.keyManager.getOutboundGroupSession(roomId) != null,
          false);
      var sess =
          await client.encryption.keyManager.createOutboundGroupSession(roomId);
      expect(
          client.encryption.keyManager.getOutboundGroupSession(roomId) != null,
          true);
      await client.encryption.keyManager.clearOrUseOutboundGroupSession(roomId);
      expect(
          client.encryption.keyManager.getOutboundGroupSession(roomId) != null,
          true);
      expect(
          client.encryption.keyManager.getInboundGroupSession(roomId,
                  sess.outboundGroupSession.session_id(), client.identityKey) !=
              null,
          true);

      // rotate after too many messages
      sess.sentMessages = 300;
      await client.encryption.keyManager.clearOrUseOutboundGroupSession(roomId);
      expect(
          client.encryption.keyManager.getOutboundGroupSession(roomId) != null,
          false);

      // rotate if device is blocked
      sess =
          await client.encryption.keyManager.createOutboundGroupSession(roomId);
      client.userDeviceKeys['@alice:example.com'].deviceKeys['JLAFKJWSCS']
          .blocked = true;
      await client.encryption.keyManager.clearOrUseOutboundGroupSession(roomId);
      expect(
          client.encryption.keyManager.getOutboundGroupSession(roomId) != null,
          false);
      client.userDeviceKeys['@alice:example.com'].deviceKeys['JLAFKJWSCS']
          .blocked = false;

      // rotate if too far in the past
      sess =
          await client.encryption.keyManager.createOutboundGroupSession(roomId);
      sess.creationTime = DateTime.now().subtract(Duration(days: 30));
      await client.encryption.keyManager.clearOrUseOutboundGroupSession(roomId);
      expect(
          client.encryption.keyManager.getOutboundGroupSession(roomId) != null,
          false);

      // rotate if user leaves
      sess =
          await client.encryption.keyManager.createOutboundGroupSession(roomId);
      final room = client.getRoomById(roomId);
      final member = room.getState('m.room.member', '@alice:example.com');
      member.content['membership'] = 'leave';
      room.mJoinedMemberCount--;
      await client.encryption.keyManager.clearOrUseOutboundGroupSession(roomId);
      expect(
          client.encryption.keyManager.getOutboundGroupSession(roomId) != null,
          false);
      member.content['membership'] = 'join';
      room.mJoinedMemberCount++;

      // do not rotate if new device is added
      sess =
          await client.encryption.keyManager.createOutboundGroupSession(roomId);
      client.userDeviceKeys['@alice:example.com'].deviceKeys['NEWDEVICE'] =
          DeviceKeys.fromJson({
        'user_id': '@alice:example.com',
        'device_id': 'NEWDEVICE',
        'algorithms': ['m.olm.v1.curve25519-aes-sha2', 'm.megolm.v1.aes-sha2'],
        'keys': {
          'curve25519:JLAFKJWSCS':
              '3C5BFWi2Y8MaVvjM8M22DBmh24PmgR0nPvJOIArzgyI',
          'ed25519:JLAFKJWSCS': 'lEuiRJBit0IG6nUf5pUzWTUEsRVVe/HJkoKuEww9ULI'
        },
      }, client);
      await client.encryption.keyManager.clearOrUseOutboundGroupSession(roomId);
      expect(
          client.encryption.keyManager.getOutboundGroupSession(roomId) != null,
          true);

      // do not rotate if new user is added
      member.content['membership'] = 'leave';
      room.mJoinedMemberCount--;
      sess =
          await client.encryption.keyManager.createOutboundGroupSession(roomId);
      member.content['membership'] = 'join';
      room.mJoinedMemberCount++;
      await client.encryption.keyManager.clearOrUseOutboundGroupSession(roomId);
      expect(
          client.encryption.keyManager.getOutboundGroupSession(roomId) != null,
          true);

      // force wipe
      sess =
          await client.encryption.keyManager.createOutboundGroupSession(roomId);
      await client.encryption.keyManager
          .clearOrUseOutboundGroupSession(roomId, wipe: true);
      expect(
          client.encryption.keyManager.getOutboundGroupSession(roomId) != null,
          false);

      // load from database
      sess =
          await client.encryption.keyManager.createOutboundGroupSession(roomId);
      client.encryption.keyManager.clearOutboundGroupSessions();
      expect(
          client.encryption.keyManager.getOutboundGroupSession(roomId) != null,
          false);
      await client.encryption.keyManager.loadOutboundGroupSession(roomId);
      expect(
          client.encryption.keyManager.getOutboundGroupSession(roomId) != null,
          true);
    });

    test('inbound group session', () async {
      final roomId = '!726s6s6q:example.com';
      final sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
      final senderKey = 'JBG7ZaPn54OBC7TuIEiylW3BZ+7WcGQhFBPB9pogbAg';
      final sessionContent = <String, dynamic>{
        'algorithm': 'm.megolm.v1.aes-sha2',
        'room_id': '!726s6s6q:example.com',
        'session_id': 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU',
        'session_key':
            'AgAAAAAQcQ6XrFJk6Prm8FikZDqfry/NbDz8Xw7T6e+/9Yf/q3YHIPEQlzv7IZMNcYb51ifkRzFejVvtphS7wwG2FaXIp4XS2obla14iKISR0X74ugB2vyb1AydIHE/zbBQ1ic5s3kgjMFlWpu/S3FQCnCrv+DPFGEt3ERGWxIl3Bl5X53IjPyVkz65oljz2TZESwz0GH/QFvyOOm8ci0q/gceaF3S7Dmafg3dwTKYwcA5xkcc+BLyrLRzB6Hn+oMAqSNSscnm4mTeT5zYibIhrzqyUTMWr32spFtI9dNR/RFSzfCw'
      };
      client.encryption.keyManager.clearInboundGroupSessions();
      expect(
          client.encryption.keyManager
                  .getInboundGroupSession(roomId, sessionId, senderKey) !=
              null,
          false);
      client.encryption.keyManager
          .setInboundGroupSession(roomId, sessionId, senderKey, sessionContent);
      await Future.delayed(Duration(milliseconds: 10));
      expect(
          client.encryption.keyManager
                  .getInboundGroupSession(roomId, sessionId, senderKey) !=
              null,
          true);
      expect(
          client.encryption.keyManager
                  .getInboundGroupSession(roomId, sessionId, 'invalid') !=
              null,
          false);

      expect(
          client.encryption.keyManager
                  .getInboundGroupSession(roomId, sessionId, senderKey) !=
              null,
          true);
      expect(
          client.encryption.keyManager
                  .getInboundGroupSession('otherroom', sessionId, senderKey) !=
              null,
          true);
      expect(
          client.encryption.keyManager
                  .getInboundGroupSession('otherroom', sessionId, 'invalid') !=
              null,
          false);
      expect(
          client.encryption.keyManager
                  .getInboundGroupSession('otherroom', 'invalid', senderKey) !=
              null,
          false);

      client.encryption.keyManager.clearInboundGroupSessions();
      expect(
          client.encryption.keyManager
                  .getInboundGroupSession(roomId, sessionId, senderKey) !=
              null,
          false);
      await client.encryption.keyManager
          .loadInboundGroupSession(roomId, sessionId, senderKey);
      expect(
          client.encryption.keyManager
                  .getInboundGroupSession(roomId, sessionId, senderKey) !=
              null,
          true);

      client.encryption.keyManager.clearInboundGroupSessions();
      expect(
          client.encryption.keyManager
                  .getInboundGroupSession(roomId, sessionId, senderKey) !=
              null,
          false);
      await client.encryption.keyManager
          .loadInboundGroupSession(roomId, sessionId, 'invalid');
      expect(
          client.encryption.keyManager
                  .getInboundGroupSession(roomId, sessionId, 'invalid') !=
              null,
          false);
    });

    test('setInboundGroupSession', () async {
      final session = olm.OutboundGroupSession();
      session.create();
      final inbound = olm.InboundGroupSession();
      inbound.create(session.session_key());
      final senderKey = client.identityKey;
      final roomId = '!someroom:example.org';
      final sessionId = inbound.session_id();
      final room = Room(id: roomId, client: client);
      client.rooms.add(room);
      // we build up an encrypted message so that we can test if it successfully decrypted afterwards
      room.states['m.room.encrypted'] = Event(
        senderId: '@test:example.com',
        type: 'm.room.encrypted',
        roomId: room.id,
        room: room,
        eventId: '12345',
        originServerTs: DateTime.now(),
        content: {
          'algorithm': 'm.megolm.v1.aes-sha2',
          'ciphertext': session.encrypt(json.encode({
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'foxies'},
          })),
          'device_id': client.deviceID,
          'sender_key': client.identityKey,
          'session_id': sessionId,
        },
        stateKey: '',
        sortOrder: 42.0,
      );
      expect(room.lastEvent.type, 'm.room.encrypted');
      // set a payload...
      var sessionPayload = <String, dynamic>{
        'algorithm': 'm.megolm.v1.aes-sha2',
        'room_id': roomId,
        'forwarding_curve25519_key_chain': [client.identityKey],
        'session_id': sessionId,
        'session_key': inbound.export_session(1),
        'sender_key': senderKey,
        'sender_claimed_ed25519_key': client.fingerprintKey,
      };
      client.encryption.keyManager.setInboundGroupSession(
          roomId, sessionId, senderKey, sessionPayload,
          forwarded: true);
      expect(
          client.encryption.keyManager
              .getInboundGroupSession(roomId, sessionId, senderKey)
              .inboundGroupSession
              .first_known_index(),
          1);
      expect(
          client.encryption.keyManager
              .getInboundGroupSession(roomId, sessionId, senderKey)
              .forwardingCurve25519KeyChain
              .length,
          1);

      // not set one with a higher first known index
      sessionPayload = <String, dynamic>{
        'algorithm': 'm.megolm.v1.aes-sha2',
        'room_id': roomId,
        'forwarding_curve25519_key_chain': [client.identityKey],
        'session_id': sessionId,
        'session_key': inbound.export_session(2),
        'sender_key': senderKey,
        'sender_claimed_ed25519_key': client.fingerprintKey,
      };
      client.encryption.keyManager.setInboundGroupSession(
          roomId, sessionId, senderKey, sessionPayload,
          forwarded: true);
      expect(
          client.encryption.keyManager
              .getInboundGroupSession(roomId, sessionId, senderKey)
              .inboundGroupSession
              .first_known_index(),
          1);
      expect(
          client.encryption.keyManager
              .getInboundGroupSession(roomId, sessionId, senderKey)
              .forwardingCurve25519KeyChain
              .length,
          1);

      // set one with a lower first known index
      sessionPayload = <String, dynamic>{
        'algorithm': 'm.megolm.v1.aes-sha2',
        'room_id': roomId,
        'forwarding_curve25519_key_chain': [client.identityKey],
        'session_id': sessionId,
        'session_key': inbound.export_session(0),
        'sender_key': senderKey,
        'sender_claimed_ed25519_key': client.fingerprintKey,
      };
      client.encryption.keyManager.setInboundGroupSession(
          roomId, sessionId, senderKey, sessionPayload,
          forwarded: true);
      expect(
          client.encryption.keyManager
              .getInboundGroupSession(roomId, sessionId, senderKey)
              .inboundGroupSession
              .first_known_index(),
          0);
      expect(
          client.encryption.keyManager
              .getInboundGroupSession(roomId, sessionId, senderKey)
              .forwardingCurve25519KeyChain
              .length,
          1);

      // not set one with a longer forwarding chain
      sessionPayload = <String, dynamic>{
        'algorithm': 'm.megolm.v1.aes-sha2',
        'room_id': roomId,
        'forwarding_curve25519_key_chain': [client.identityKey, 'beep'],
        'session_id': sessionId,
        'session_key': inbound.export_session(0),
        'sender_key': senderKey,
        'sender_claimed_ed25519_key': client.fingerprintKey,
      };
      client.encryption.keyManager.setInboundGroupSession(
          roomId, sessionId, senderKey, sessionPayload,
          forwarded: true);
      expect(
          client.encryption.keyManager
              .getInboundGroupSession(roomId, sessionId, senderKey)
              .inboundGroupSession
              .first_known_index(),
          0);
      expect(
          client.encryption.keyManager
              .getInboundGroupSession(roomId, sessionId, senderKey)
              .forwardingCurve25519KeyChain
              .length,
          1);

      // set one with a shorter forwarding chain
      sessionPayload = <String, dynamic>{
        'algorithm': 'm.megolm.v1.aes-sha2',
        'room_id': roomId,
        'forwarding_curve25519_key_chain': [],
        'session_id': sessionId,
        'session_key': inbound.export_session(0),
        'sender_key': senderKey,
        'sender_claimed_ed25519_key': client.fingerprintKey,
      };
      client.encryption.keyManager.setInboundGroupSession(
          roomId, sessionId, senderKey, sessionPayload,
          forwarded: true);
      expect(
          client.encryption.keyManager
              .getInboundGroupSession(roomId, sessionId, senderKey)
              .inboundGroupSession
              .first_known_index(),
          0);
      expect(
          client.encryption.keyManager
              .getInboundGroupSession(roomId, sessionId, senderKey)
              .forwardingCurve25519KeyChain
              .length,
          0);

      // test that it decrypted the last event
      expect(room.lastEvent.type, 'm.room.message');
      expect(room.lastEvent.content['body'], 'foxies');

      inbound.free();
      session.free();
    });

    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
    });
  });
}
