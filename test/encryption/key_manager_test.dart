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

import 'dart:convert';

import 'package:olm/olm.dart' as olm;
import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import '../fake_client.dart';
import '../fake_matrix_api.dart';

void main() {
  group('Key Manager', () {
    Logs().level = Level.error;
    var olmEnabled = true;

    late Client client;

    test('setupClient', () async {
      try {
        await olm.init();
        olm.get_library_version();
      } catch (e) {
        olmEnabled = false;
        Logs().w('[LibOlm] Failed to load LibOlm', e);
      }
      Logs().i('[LibOlm] Enabled: $olmEnabled');
      if (!olmEnabled) return;

      client = await getClient();
    });

    test('handle new m.room_key', () async {
      if (!olmEnabled) return;
      final validSessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
      final validSenderKey = 'JBG7ZaPn54OBC7TuIEiylW3BZ+7WcGQhFBPB9pogbAg';
      final sessionKey =
          'AgAAAAAQcQ6XrFJk6Prm8FikZDqfry/NbDz8Xw7T6e+/9Yf/q3YHIPEQlzv7IZMNcYb51ifkRzFejVvtphS7wwG2FaXIp4XS2obla14iKISR0X74ugB2vyb1AydIHE/zbBQ1ic5s3kgjMFlWpu/S3FQCnCrv+DPFGEt3ERGWxIl3Bl5X53IjPyVkz65oljz2TZESwz0GH/QFvyOOm8ci0q/gceaF3S7Dmafg3dwTKYwcA5xkcc+BLyrLRzB6Hn+oMAqSNSscnm4mTeT5zYibIhrzqyUTMWr32spFtI9dNR/RFSzfCw';

      client.encryption!.keyManager.clearInboundGroupSessions();
      var event = ToDeviceEvent(
          sender: '@alice:example.com',
          type: 'm.room_key',
          content: {
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'room_id': '!726s6s6q:example.com',
            'session_id': validSessionId,
            'session_key': sessionKey,
          },
          encryptedContent: {
            'sender_key': validSenderKey,
          });
      await client.encryption!.keyManager.handleToDeviceEvent(event);
      expect(
          client.encryption!.keyManager.getInboundGroupSession(
                  '!726s6s6q:example.com', validSessionId) !=
              null,
          true);

      // now test a few invalid scenarios

      // not encrypted
      client.encryption!.keyManager.clearInboundGroupSessions();
      event = ToDeviceEvent(
          sender: '@alice:example.com',
          type: 'm.room_key',
          content: {
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'room_id': '!726s6s6q:example.com',
            'session_id': validSessionId,
            'session_key': sessionKey,
          });
      await client.encryption!.keyManager.handleToDeviceEvent(event);
      expect(
          client.encryption!.keyManager.getInboundGroupSession(
                  '!726s6s6q:example.com', validSessionId) !=
              null,
          false);
    });

    test('outbound group session', () async {
      if (!olmEnabled) return;
      final roomId = '!726s6s6q:example.com';
      expect(
          client.encryption!.keyManager.getOutboundGroupSession(roomId) != null,
          false);
      var sess = await client.encryption!.keyManager
          .createOutboundGroupSession(roomId);
      expect(
          client.encryption!.keyManager.getOutboundGroupSession(roomId) != null,
          true);
      await client.encryption!.keyManager
          .clearOrUseOutboundGroupSession(roomId);
      expect(
          client.encryption!.keyManager.getOutboundGroupSession(roomId) != null,
          true);
      var inbound = client.encryption!.keyManager.getInboundGroupSession(
          roomId, sess.outboundGroupSession!.session_id());
      expect(inbound != null, true);
      expect(
          inbound!.allowedAtIndex['@alice:example.com']
              ?['L+4+JCl8MD63dgo8z5Ta+9QAHXiANyOVSfgbHA5d3H8'],
          0);
      expect(
          inbound.allowedAtIndex['@alice:example.com']
              ?['wMIDhiQl5jEXQrTB03ePOSQfR8sA/KMrW0CIfFfXKEE'],
          0);

      // rotate after too many messages
      Iterable.generate(300).forEach((_) {
        sess.outboundGroupSession!.encrypt('some string');
      });
      await client.encryption!.keyManager
          .clearOrUseOutboundGroupSession(roomId);
      expect(
          client.encryption!.keyManager.getOutboundGroupSession(roomId) != null,
          false);

      // rotate if device is blocked
      sess = await client.encryption!.keyManager
          .createOutboundGroupSession(roomId);
      client.userDeviceKeys['@alice:example.com']!.deviceKeys['JLAFKJWSCS']!
          .blocked = true;
      await client.encryption!.keyManager
          .clearOrUseOutboundGroupSession(roomId);
      expect(
          client.encryption!.keyManager.getOutboundGroupSession(roomId) != null,
          false);
      client.userDeviceKeys['@alice:example.com']!.deviceKeys['JLAFKJWSCS']!
          .blocked = false;

      // lazy-create if it would rotate
      sess = await client.encryption!.keyManager
          .createOutboundGroupSession(roomId);
      final oldSessKey = sess.outboundGroupSession!.session_key();
      client.userDeviceKeys['@alice:example.com']!.deviceKeys['JLAFKJWSCS']!
          .blocked = true;
      await client.encryption!.keyManager.prepareOutboundGroupSession(roomId);
      expect(
          client.encryption!.keyManager.getOutboundGroupSession(roomId) != null,
          true);
      expect(
          client.encryption!.keyManager
                  .getOutboundGroupSession(roomId)!
                  .outboundGroupSession!
                  .session_key() !=
              oldSessKey,
          true);
      client.userDeviceKeys['@alice:example.com']!.deviceKeys['JLAFKJWSCS']!
          .blocked = false;

      // rotate if too far in the past
      sess = await client.encryption!.keyManager
          .createOutboundGroupSession(roomId);
      sess.creationTime = DateTime.now().subtract(Duration(days: 30));
      await client.encryption!.keyManager
          .clearOrUseOutboundGroupSession(roomId);
      expect(
          client.encryption!.keyManager.getOutboundGroupSession(roomId) != null,
          false);

      // rotate if user leaves
      sess = await client.encryption!.keyManager
          .createOutboundGroupSession(roomId);
      final room = client.getRoomById(roomId)!;
      final member = room.getState('m.room.member', '@alice:example.com');
      member!.content['membership'] = 'leave';
      room.summary.mJoinedMemberCount = room.summary.mJoinedMemberCount! - 1;
      await client.encryption!.keyManager
          .clearOrUseOutboundGroupSession(roomId);
      expect(
          client.encryption!.keyManager.getOutboundGroupSession(roomId) != null,
          false);
      member.content['membership'] = 'join';
      room.summary.mJoinedMemberCount = room.summary.mJoinedMemberCount! + 1;

      // do not rotate if new device is added
      sess = await client.encryption!.keyManager
          .createOutboundGroupSession(roomId);
      sess.outboundGroupSession!.encrypt(
          'foxies'); // so that the new device will have a different index
      client.userDeviceKeys['@alice:example.com']?.deviceKeys['NEWDEVICE'] =
          DeviceKeys.fromJson({
        'user_id': '@alice:example.com',
        'device_id': 'NEWDEVICE',
        'algorithms': [
          AlgorithmTypes.olmV1Curve25519AesSha2,
          AlgorithmTypes.megolmV1AesSha2
        ],
        'keys': {
          'curve25519:NEWDEVICE': 'bnKQp6pPW0l9cGoIgHpBoK5OUi4h0gylJ7upc4asFV8',
          'ed25519:NEWDEVICE': 'ZZhPdvWYg3MRpGy2MwtI+4MHXe74wPkBli5hiEOUi8Y'
        },
        'signatures': {
          '@alice:example.com': {
            'ed25519:NEWDEVICE':
                '94GSg8N9vNB8wyWHJtKaaX3MGNWPVOjBatJM+TijY6B1RlDFJT5Cl1h/tjr17AoQz0CDdOf6uFhrYsBkH1/ABg'
          }
        }
      }, client);
      await client.encryption!.keyManager
          .clearOrUseOutboundGroupSession(roomId);
      expect(
          client.encryption!.keyManager.getOutboundGroupSession(roomId) != null,
          true);
      inbound = client.encryption!.keyManager.getInboundGroupSession(
          roomId, sess.outboundGroupSession!.session_id());
      expect(
          inbound!.allowedAtIndex['@alice:example.com']
              ?['L+4+JCl8MD63dgo8z5Ta+9QAHXiANyOVSfgbHA5d3H8'],
          0);
      expect(
          inbound.allowedAtIndex['@alice:example.com']
              ?['wMIDhiQl5jEXQrTB03ePOSQfR8sA/KMrW0CIfFfXKEE'],
          0);
      expect(
          inbound.allowedAtIndex['@alice:example.com']
              ?['bnKQp6pPW0l9cGoIgHpBoK5OUi4h0gylJ7upc4asFV8'],
          1);

      // do not rotate if new user is added
      member.content['membership'] = 'leave';
      room.summary.mJoinedMemberCount = room.summary.mJoinedMemberCount! - 1;
      sess = await client.encryption!.keyManager
          .createOutboundGroupSession(roomId);
      member.content['membership'] = 'join';
      room.summary.mJoinedMemberCount = room.summary.mJoinedMemberCount! + 1;
      await client.encryption!.keyManager
          .clearOrUseOutboundGroupSession(roomId);
      expect(
          client.encryption!.keyManager.getOutboundGroupSession(roomId) != null,
          true);

      // force wipe
      sess = await client.encryption!.keyManager
          .createOutboundGroupSession(roomId);
      await client.encryption!.keyManager
          .clearOrUseOutboundGroupSession(roomId, wipe: true);
      expect(
          client.encryption!.keyManager.getOutboundGroupSession(roomId) != null,
          false);

      // load from database
      sess = await client.encryption!.keyManager
          .createOutboundGroupSession(roomId);
      client.encryption!.keyManager.clearOutboundGroupSessions();
      expect(
          client.encryption!.keyManager.getOutboundGroupSession(roomId) != null,
          false);
      await client.encryption!.keyManager.loadOutboundGroupSession(roomId);
      expect(
          client.encryption!.keyManager.getOutboundGroupSession(roomId) != null,
          true);
    });

    test('inbound group session', () async {
      if (!olmEnabled) return;
      final roomId = '!726s6s6q:example.com';
      final sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
      final senderKey = 'JBG7ZaPn54OBC7TuIEiylW3BZ+7WcGQhFBPB9pogbAg';
      final sessionContent = <String, dynamic>{
        'algorithm': AlgorithmTypes.megolmV1AesSha2,
        'room_id': '!726s6s6q:example.com',
        'session_id': 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU',
        'session_key':
            'AgAAAAAQcQ6XrFJk6Prm8FikZDqfry/NbDz8Xw7T6e+/9Yf/q3YHIPEQlzv7IZMNcYb51ifkRzFejVvtphS7wwG2FaXIp4XS2obla14iKISR0X74ugB2vyb1AydIHE/zbBQ1ic5s3kgjMFlWpu/S3FQCnCrv+DPFGEt3ERGWxIl3Bl5X53IjPyVkz65oljz2TZESwz0GH/QFvyOOm8ci0q/gceaF3S7Dmafg3dwTKYwcA5xkcc+BLyrLRzB6Hn+oMAqSNSscnm4mTeT5zYibIhrzqyUTMWr32spFtI9dNR/RFSzfCw'
      };
      client.encryption!.keyManager.clearInboundGroupSessions();
      expect(
          client.encryption!.keyManager
                  .getInboundGroupSession(roomId, sessionId) !=
              null,
          false);
      await client.encryption!.keyManager
          .setInboundGroupSession(roomId, sessionId, senderKey, sessionContent);
      expect(
          client.encryption!.keyManager
                  .getInboundGroupSession(roomId, sessionId) !=
              null,
          true);

      expect(
          client.encryption!.keyManager
                  .getInboundGroupSession(roomId, sessionId) !=
              null,
          true);

      client.encryption!.keyManager.clearInboundGroupSessions();
      expect(
          client.encryption!.keyManager
                  .getInboundGroupSession(roomId, sessionId) !=
              null,
          false);
      await client.encryption!.keyManager
          .loadInboundGroupSession(roomId, sessionId);
      expect(
          client.encryption!.keyManager
                  .getInboundGroupSession(roomId, sessionId) !=
              null,
          true);

      client.encryption!.keyManager.clearInboundGroupSessions();
      expect(
          client.encryption!.keyManager
                  .getInboundGroupSession(roomId, sessionId) !=
              null,
          false);
    });

    test('setInboundGroupSession', () async {
      if (!olmEnabled) return;
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
      room.setState(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.encrypted',
          room: room,
          eventId: '12345',
          originServerTs: DateTime.now(),
          content: {
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'ciphertext': session.encrypt(json.encode({
              'type': 'm.room.message',
              'content': {'msgtype': 'm.text', 'body': 'foxies'},
            })),
            'device_id': client.deviceID,
            'sender_key': client.identityKey,
            'session_id': sessionId,
          },
          stateKey: '',
        ),
      );
      expect(room.lastEvent?.type, 'm.room.encrypted');
      // set a payload...
      var sessionPayload = <String, dynamic>{
        'algorithm': AlgorithmTypes.megolmV1AesSha2,
        'room_id': roomId,
        'forwarding_curve25519_key_chain': [client.identityKey],
        'session_id': sessionId,
        'session_key': inbound.export_session(1),
        'sender_key': senderKey,
        'sender_claimed_ed25519_key': client.fingerprintKey,
      };
      await client.encryption!.keyManager.setInboundGroupSession(
          roomId, sessionId, senderKey, sessionPayload,
          forwarded: true);
      expect(
          client.encryption!.keyManager
              .getInboundGroupSession(roomId, sessionId)
              ?.inboundGroupSession
              ?.first_known_index(),
          1);
      expect(
          client.encryption!.keyManager
              .getInboundGroupSession(roomId, sessionId)
              ?.forwardingCurve25519KeyChain
              .length,
          1);

      // not set one with a higher first known index
      sessionPayload = <String, dynamic>{
        'algorithm': AlgorithmTypes.megolmV1AesSha2,
        'room_id': roomId,
        'forwarding_curve25519_key_chain': [client.identityKey],
        'session_id': sessionId,
        'session_key': inbound.export_session(2),
        'sender_key': senderKey,
        'sender_claimed_ed25519_key': client.fingerprintKey,
      };
      await client.encryption!.keyManager.setInboundGroupSession(
          roomId, sessionId, senderKey, sessionPayload,
          forwarded: true);
      expect(
          client.encryption!.keyManager
              .getInboundGroupSession(roomId, sessionId)
              ?.inboundGroupSession
              ?.first_known_index(),
          1);
      expect(
          client.encryption!.keyManager
              .getInboundGroupSession(roomId, sessionId)
              ?.forwardingCurve25519KeyChain
              .length,
          1);

      // set one with a lower first known index
      sessionPayload = <String, dynamic>{
        'algorithm': AlgorithmTypes.megolmV1AesSha2,
        'room_id': roomId,
        'forwarding_curve25519_key_chain': [client.identityKey],
        'session_id': sessionId,
        'session_key': inbound.export_session(0),
        'sender_key': senderKey,
        'sender_claimed_ed25519_key': client.fingerprintKey,
      };
      await client.encryption!.keyManager.setInboundGroupSession(
          roomId, sessionId, senderKey, sessionPayload,
          forwarded: true);
      expect(
          client.encryption!.keyManager
              .getInboundGroupSession(roomId, sessionId)
              ?.inboundGroupSession
              ?.first_known_index(),
          0);
      expect(
          client.encryption!.keyManager
              .getInboundGroupSession(roomId, sessionId)
              ?.forwardingCurve25519KeyChain
              .length,
          1);

      // not set one with a longer forwarding chain
      sessionPayload = <String, dynamic>{
        'algorithm': AlgorithmTypes.megolmV1AesSha2,
        'room_id': roomId,
        'forwarding_curve25519_key_chain': [client.identityKey, 'beep'],
        'session_id': sessionId,
        'session_key': inbound.export_session(0),
        'sender_key': senderKey,
        'sender_claimed_ed25519_key': client.fingerprintKey,
      };
      await client.encryption!.keyManager.setInboundGroupSession(
          roomId, sessionId, senderKey, sessionPayload,
          forwarded: true);
      expect(
          client.encryption!.keyManager
              .getInboundGroupSession(roomId, sessionId)
              ?.inboundGroupSession
              ?.first_known_index(),
          0);
      expect(
          client.encryption!.keyManager
              .getInboundGroupSession(roomId, sessionId)
              ?.forwardingCurve25519KeyChain
              .length,
          1);

      // set one with a shorter forwarding chain
      sessionPayload = <String, dynamic>{
        'algorithm': AlgorithmTypes.megolmV1AesSha2,
        'room_id': roomId,
        'forwarding_curve25519_key_chain': [],
        'session_id': sessionId,
        'session_key': inbound.export_session(0),
        'sender_key': senderKey,
        'sender_claimed_ed25519_key': client.fingerprintKey,
      };
      await client.encryption!.keyManager.setInboundGroupSession(
          roomId, sessionId, senderKey, sessionPayload,
          forwarded: true);
      expect(
          client.encryption!.keyManager
              .getInboundGroupSession(roomId, sessionId)
              ?.inboundGroupSession
              ?.first_known_index(),
          0);
      expect(
          client.encryption!.keyManager
              .getInboundGroupSession(roomId, sessionId)
              ?.forwardingCurve25519KeyChain
              .length,
          0);

      // test that it decrypted the last event
      expect(room.lastEvent?.type, 'm.room.message');
      expect(room.lastEvent?.content['body'], 'foxies');

      inbound.free();
      session.free();
    });

    test('Reused deviceID attack', () async {
      if (!olmEnabled) return;
      Logs().level = Level.warning;

      // Ensure the device came from sync
      expect(
          client.userDeviceKeys['@alice:example.com']
                  ?.deviceKeys['JLAFKJWSCS'] !=
              null,
          true);

      // Alice removes her device
      client.userDeviceKeys['@alice:example.com']?.deviceKeys
          .remove('JLAFKJWSCS');

      // Alice adds her device with same device ID but different keys
      final oldResp =
          FakeMatrixApi.currentApi?.api['POST']?['/client/v3/keys/query'](null);
      FakeMatrixApi.currentApi?.api['POST']?['/client/v3/keys/query'] = (_) {
        oldResp['device_keys']['@alice:example.com']['JLAFKJWSCS'] = {
          'user_id': '@alice:example.com',
          'device_id': 'JLAFKJWSCS',
          'algorithms': [
            'm.olm.v1.curve25519-aes-sha2',
            'm.megolm.v1.aes-sha2'
          ],
          'keys': {
            'curve25519:JLAFKJWSCS':
                'WbwrNyD7nvtmcLQ0TTuVPFGJq6JznfjrVsjIpmBqvDw',
            'ed25519:JLAFKJWSCS': 'vl0d54pTVRcvBgUzoQFa8e6TldHWG9O8bh0iuIvgd/I'
          },
          'signatures': {
            '@alice:example.com': {
              'ed25519:JLAFKJWSCS':
                  's/L86jLa8BTroL8GsBeqO0gRLC3ZrSA7Gch6UoLI2SefC1+1ycmnP9UGbLPh3qBJOmlhczMpBLZwelg87qNNDA'
            }
          }
        };
        return oldResp;
      };
      client.userDeviceKeys['@alice:example.com']!.outdated = true;
      await client.updateUserDeviceKeys();
      expect(
          client.userDeviceKeys['@alice:example.com']?.deviceKeys['JLAFKJWSCS'],
          null);
    });

    test('dispose client', () async {
      if (!olmEnabled) return;
      await client.dispose(closeDatabase: false);
    });
  });
}
