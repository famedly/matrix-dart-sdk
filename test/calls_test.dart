import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import 'fake_client.dart';
import 'webrtc_stub.dart';

void main() {
  late Client matrix;
  late Room room;

  group('Call Tests', () {
    Logs().level = Level.info;

    test('Login', () async {
      matrix = await getClient();
    });

    test('Create from json', () async {
      final id = '!localpart:server.abc';
      final membership = Membership.join;

      room = Room(
        client: matrix,
        id: id,
        membership: membership,
        prev_batch: '',
      );
    });

    test('Test call methods', () async {
      final call = CallSession(CallOptions()..room = room);
      await call.sendInviteToCall(room, '1234', 1234, '4567', '7890', 'sdp',
          txid: '1234');
      await call.sendAnswerCall(room, '1234', 'sdp', '4567', txid: '1234');
      await call.sendCallCandidates(room, '1234', '4567', [], txid: '1234');
      await call.sendSelectCallAnswer(room, '1234', '4567', '6789',
          txid: '1234');
      await call.sendCallReject(room, '1234', '4567', 'busy', txid: '1234');
      await call.sendCallNegotiate(room, '1234', 1234, '4567', 'sdp',
          txid: '1234');
      await call.sendHangupCall(room, '1234', '4567', 'user_hangup',
          txid: '1234');
      await call.sendAssertedIdentity(
          room,
          '1234',
          '4567',
          AssertedIdentity()
            ..displayName = 'name'
            ..id = 'some_id',
          txid: '1234');
      await call.sendCallReplaces(room, '1234', '4567', CallReplaces(),
          txid: '1234');
      await call.sendSDPStreamMetadataChanged(
          room, '1234', '4567', SDPStreamMetadata({}),
          txid: '1234');
    });
    test('Test call lifetime', () async {
      final voip = VoIP(matrix, MockWebRTCDelegate());
      expect(voip.currentCID, null);
      // persist normal room messages
      await matrix.handleSync(SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(join: {
            room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(events: [
              MatrixEvent(
                type: 'm.call.invite',
                content: {
                  'lifetime': 60000,
                  'call_id': '1702472924955oq1uQbNAfU7wAaEA',
                  'party_id': 'DPCIPPBGPO',
                  'offer': {'type': 'offer', 'sdp': 'sdp'}
                },
                senderId: '@alice:testing.com',
                eventId: 'newevent',
                originServerTs: DateTime.utc(1969),
              )
            ]))
          })));
      await Future.delayed(Duration(seconds: 3));
      // confirm that no call got created after 3 seconds, which is
      // expected in this case because the originTs was old asf
      expect(voip.currentCID, null);

      // persist normal room messages
      await matrix.handleSync(SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(join: {
            room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(events: [
              MatrixEvent(
                unsigned: {'age': 60001},
                type: 'm.call.invite',
                content: {
                  'lifetime': 60000,
                  'call_id': 'unsignedTsInvalidCall',
                  'party_id': 'DPCIPPBGPO',
                  'offer': {'type': 'offer', 'sdp': 'sdp'}
                },
                senderId: '@alice:testing.com',
                eventId: 'newevent',
                originServerTs: DateTime.now(),
              )
            ]))
          })));
      await Future.delayed(Duration(seconds: 3));
      // confirm that no call got created after 3 seconds, which is
      // expected in this case because age was older than lifetime
      expect(voip.currentCID, null);
      // persist normal room messages
      await matrix.handleSync(SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(join: {
            room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(events: [
              MatrixEvent(
                type: 'm.call.invite',
                content: {
                  'lifetime': 60000,
                  'call_id': 'originTsValidCall',
                  'party_id': 'DPCIPPBGPO',
                  'offer': {'type': 'offer', 'sdp': 'sdp'}
                },
                senderId: '@alice:testing.com',
                eventId: 'newevent',
                originServerTs: DateTime.now(),
              )
            ]))
          })));
      while (voip.currentCID != 'originTsValidCall') {
        // call invite looks valid, call should be created now :D
        await Future.delayed(Duration(milliseconds: 50));
        Logs().d('Waiting for currentCID to update');
      }
      expect(voip.currentCID, 'originTsValidCall');
      final call = voip.calls[voip.currentCID]!;
      await call.answer(txid: '1234');
      expect(call.state, CallState.kConnecting);
    });
  });
}
