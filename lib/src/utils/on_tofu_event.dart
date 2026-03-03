import 'package:matrix/matrix.dart';

Future<void> sendTofuEvent(Room room, Set<String> userIds) async {
  await room.client.database.transaction(() async {
    await room.client.handleSync(
      SyncUpdate(
        nextBatch: '',
        rooms: RoomsUpdate(
          join: {
            room.id: JoinedRoomUpdate(
              timeline: TimelineUpdate(
                events: [
                  MatrixEvent(
                    eventId:
                        '\$_local_event_${room.client.generateUniqueTransactionId()}',
                    content: {
                      'body':
                          '${userIds.join(', ')} has/have reset their encryption keys',
                      'users': userIds.toList(),
                    },
                    type: EventTypes.TofuNotification,
                    senderId: room.client.userID!,
                    originServerTs: DateTime.now(),
                  ),
                ],
              ),
            ),
          },
        ),
      ),
    );
  });
}
