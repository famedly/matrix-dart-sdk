import 'package:matrix/matrix_api_lite/model/sync_update.dart';
import 'package:matrix/msc_extensions/msc_4354_sticky_events/models.dart';
import 'package:test/test.dart';

void main() {
  group('StickyEventDuration', () {
    test('fromJson parses durationMs', () {
      final duration = StickyEventDuration.fromJson(
        {MSC4354ExtensionKeys.stickyDurationMs: 30000},
      );
      expect(duration.durationMs, 30000);
    });

    test('fromJson defaults to 0 when key is missing', () {
      final duration = StickyEventDuration.fromJson({});
      expect(duration.durationMs, 0);
    });

    test('toJson serializes correctly', () {
      final json = StickyEventDuration(durationMs: 60000).toJson();
      expect(json[MSC4354ExtensionKeys.stickyDurationMs], 60000);
    });
  });

  group('StickyEvent', () {
    Map<String, Object?> makeStickyEventJson({
      Map<String, Object?>? content,
      Map<String, Object?>? unsigned,
      Map<String, Object?>? sticky,
    }) =>
        {
          'type': 'm.room.message',
          'content': content ?? {'body': 'hello'},
          'sender': '@alice:example.com',
          'event_id': '\$event1',
          'origin_server_ts': 1234567890,
          if (sticky != null) MSC4354ExtensionKeys.sticky: sticky,
          if (unsigned != null) 'unsigned': unsigned,
        };

    test('fromJson parses correctly', () {
      final event = StickyEvent.fromJson(
        makeStickyEventJson(
          sticky: {MSC4354ExtensionKeys.stickyDurationMs: 45000},
        ),
      );
      expect(event.type, 'm.room.message');
      expect(event.senderId, '@alice:example.com');
      expect(event.eventId, '\$event1');
      expect(event.sticky.durationMs, 45000);
    });

    test('fromJson defaults sticky when key is absent', () {
      final event = StickyEvent.fromJson(makeStickyEventJson());
      expect(event.sticky.durationMs, 0);
    });

    test('toJson round-trips correctly', () {
      final json = StickyEvent.fromJson(
        makeStickyEventJson(
          sticky: {MSC4354ExtensionKeys.stickyDurationMs: 45000},
        ),
      ).toJson();
      expect(json['type'], 'm.room.message');
      expect(json['event_id'], '\$event1');
      final s = json[MSC4354ExtensionKeys.sticky] as Map;
      expect(s[MSC4354ExtensionKeys.stickyDurationMs], 45000);
    });

    test('stickyKey returns key from content', () {
      final event = StickyEvent.fromJson(
        makeStickyEventJson(
          content: {
            MSC4354StickyEventContent.stickyKey: 'my_key',
            'body': 'hi'
          },
        ),
      );
      expect(event.stickyKey, 'my_key');
    });

    test('stickyKey returns null when missing', () {
      final event = StickyEvent.fromJson(makeStickyEventJson());
      expect(event.stickyKey, isNull);
    });

    test('unsignedDurationTtlMs returns Duration when present', () {
      final event = StickyEvent.fromJson(
        makeStickyEventJson(
          unsigned: {MSC4354StickyEventContent.unsignedDurationTtlMs: 30000},
        ),
      );
      expect(event.unsignedDurationTtlMs, const Duration(milliseconds: 30000));
    });

    test('unsignedDurationTtlMs returns null when unsigned is missing', () {
      final event = StickyEvent.fromJson(makeStickyEventJson());
      expect(event.unsignedDurationTtlMs, isNull);
    });
  });

  group('StickyEventsUpdate', () {
    test('fromJson parses events list', () {
      final update = StickyEventsUpdate.fromJson({
        'events': [
          {
            'type': 'm.room.message',
            'content': {'body': 'hello'},
            'sender': '@alice:example.com',
            'event_id': '\$event1',
            'origin_server_ts': 1234567890,
            MSC4354ExtensionKeys.sticky: {
              MSC4354ExtensionKeys.stickyDurationMs: 10000,
            },
          },
        ],
      });
      expect(update.events.length, 1);
      expect(update.events.first.eventId, '\$event1');
      expect(update.events.first.sticky.durationMs, 10000);
    });

    test('fromJson defaults to empty list when events is null', () {
      expect(StickyEventsUpdate.fromJson({}).events, isEmpty);
    });

    test('toJson serializes events', () {
      final update = StickyEventsUpdate(
        events: [
          StickyEvent.fromJson({
            'type': 'm.room.message',
            'content': {'body': 'hello'},
            'sender': '@alice:example.com',
            'event_id': '\$event1',
            'origin_server_ts': 1234567890,
          }),
        ],
      );
      expect((update.toJson()['events'] as List).length, 1);
    });
  });

  group('JoinedRoomUpdate with sticky events', () {
    test('fromJson parses sticky field', () {
      final update = JoinedRoomUpdate.fromJson({
        MSC4354ExtensionKeys.syncJoinedRoomSticky: {
          'events': [
            {
              'type': 'm.room.message',
              'content': {'body': 'sticky msg'},
              'sender': '@alice:example.com',
              'event_id': '\$sticky1',
              'origin_server_ts': 1234567890,
              MSC4354ExtensionKeys.sticky: {
                MSC4354ExtensionKeys.stickyDurationMs: 20000,
              },
            },
          ],
        },
      });
      expect(update.sticky, isNotNull);
      expect(update.sticky!.events.length, 1);
      expect(update.sticky!.events.first.eventId, '\$sticky1');
      expect(update.sticky!.events.first.sticky.durationMs, 20000);
    });

    test('fromJson has null sticky when key is absent', () {
      final update = JoinedRoomUpdate.fromJson({});
      expect(update.sticky, isNull);
    });

    test('toJson includes sticky when present', () {
      final update = JoinedRoomUpdate(
        sticky: StickyEventsUpdate(
          events: [
            StickyEvent.fromJson({
              'type': 'm.room.message',
              'content': {'body': 'test'},
              'sender': '@alice:example.com',
              'event_id': '\$s1',
              'origin_server_ts': 1234567890,
              MSC4354ExtensionKeys.sticky: {
                MSC4354ExtensionKeys.stickyDurationMs: 15000,
              },
            }),
          ],
        ),
      );
      final json = update.toJson();
      expect(
        json.containsKey(MSC4354ExtensionKeys.syncJoinedRoomSticky),
        true,
      );
      final stickyJson = json[MSC4354ExtensionKeys.syncJoinedRoomSticky] as Map;
      expect((stickyJson['events'] as List).length, 1);
    });

    test('toJson omits sticky when null', () {
      final json = JoinedRoomUpdate().toJson();
      expect(
        json.containsKey(MSC4354ExtensionKeys.syncJoinedRoomSticky),
        false,
      );
    });
  });
}
