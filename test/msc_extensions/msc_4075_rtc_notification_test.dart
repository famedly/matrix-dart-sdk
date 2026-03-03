import 'dart:convert';

import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import '../fake_client.dart';

void main() {
  late Client client;
  late Room room;

  setUpAll(() async {
    client = await getClient();
    room = Room(id: '!1234:fakeServer.notExisting', client: client);
  });

  group('RtcNotificationType', () {
    test('fromValue returns correct type', () {
      expect(RtcNotificationType.fromValue('ring'), RtcNotificationType.ring);
      expect(
        RtcNotificationType.fromValue('notification'),
        RtcNotificationType.notification,
      );
      expect(RtcNotificationType.fromValue('invalid'), null);
      expect(RtcNotificationType.fromValue(null), null);
    });
  });

  group('RtcNotificationContent', () {
    late DateTime now;

    setUp(() {
      now = DateTime.now();
    });

    test('create factory with defaults and custom lifetime', () {
      final defaultContent = RtcNotificationContent.create(
        type: RtcNotificationType.ring,
      );
      expect(defaultContent.notificationType, RtcNotificationType.ring);
      expect(defaultContent.lifetime, RtcNotificationContent.defaultLifetime);
      expect(
        defaultContent.senderTs.difference(now).inSeconds.abs(),
        lessThan(2),
      );

      final customContent = RtcNotificationContent.create(
        type: RtcNotificationType.notification,
        lifetime: Duration(minutes: 1),
      );
      expect(customContent.lifetime, Duration(minutes: 1));
    });

    test('fromEvent parses correctly and handles defaults', () {
      final validEvent = Event.fromJson(
        {
          'type': RtcNotificationContent.eventType,
          'sender': '@alice:example.com',
          'event_id': '\$event1',
          'origin_server_ts': now.millisecondsSinceEpoch,
          'content': {
            'sender_ts': now.millisecondsSinceEpoch,
            'lifetime': 45000,
            'notification_type': 'ring',
          },
        },
        room,
      );
      final content = RtcNotificationContent.fromEvent(validEvent);
      expect(
        content.senderTs,
        DateTime.fromMillisecondsSinceEpoch(now.millisecondsSinceEpoch),
      );
      expect(content.lifetime, Duration(milliseconds: 45000));
      expect(content.notificationType, RtcNotificationType.ring);

      final missingLifetimeEvent = Event.fromJson(
        {
          'type': RtcNotificationContent.eventType,
          'sender': '@alice:example.com',
          'event_id': '\$event2',
          'origin_server_ts': now.millisecondsSinceEpoch,
          'content': {
            'sender_ts': now.millisecondsSinceEpoch,
            'notification_type': 'notification',
          },
        },
        room,
      );
      expect(
        RtcNotificationContent.fromEvent(missingLifetimeEvent).lifetime,
        RtcNotificationContent.defaultLifetime,
      );
    });

    test('fromEvent throws on invalid notification_type', () {
      final event = Event.fromJson(
        {
          'type': RtcNotificationContent.eventType,
          'sender': '@alice:example.com',
          'event_id': '\$event1',
          'origin_server_ts': now.millisecondsSinceEpoch,
          'content': {
            'sender_ts': now.millisecondsSinceEpoch,
            'notification_type': 'invalid',
          },
        },
        room,
      );

      expect(
        () => RtcNotificationContent.fromEvent(event),
        throwsArgumentError,
      );
    });

    test('toJson serializes correctly', () {
      final content = RtcNotificationContent(
        senderTs: now,
        notificationType: RtcNotificationType.ring,
        lifetime: Duration(seconds: 60),
      );

      final json = content.toJson();
      expect(json['sender_ts'], now.millisecondsSinceEpoch);
      expect(json['lifetime'], 60000);
      expect(json['notification_type'], 'ring');
    });

    test('cappedLifetime handles edge cases', () {
      final validContent = RtcNotificationContent.create(
        type: RtcNotificationType.ring,
        lifetime: Duration(seconds: 30),
      );
      expect(validContent.cappedLifetime, Duration(seconds: 30));

      final exceededContent = RtcNotificationContent.create(
        type: RtcNotificationType.ring,
        lifetime: Duration(minutes: 5),
      );
      expect(
        exceededContent.cappedLifetime,
        RtcNotificationContent.maxLifetime,
      );

      final negativeContent = RtcNotificationContent(
        senderTs: now,
        notificationType: RtcNotificationType.ring,
        lifetime: Duration(seconds: -10),
      );
      expect(negativeContent.cappedLifetime, Duration.zero);
    });

    test('getEffectiveTimestamp with clock deviation', () {
      final senderTs = now;
      final smallDeviation = now.add(Duration(seconds: 5));
      final largeDeviation = now.add(Duration(seconds: 25));
      final content = RtcNotificationContent(
        senderTs: senderTs,
        notificationType: RtcNotificationType.ring,
      );

      expect(content.getEffectiveTimestamp(smallDeviation), senderTs);
      expect(content.getEffectiveTimestamp(largeDeviation), largeDeviation);
    });

    test('isExpired checks notification validity', () {
      final activeContent = RtcNotificationContent(
        senderTs: now.subtract(Duration(seconds: 10)),
        notificationType: RtcNotificationType.ring,
        lifetime: Duration(seconds: 30),
      );
      expect(
        activeContent.isExpired(now.subtract(Duration(seconds: 10))),
        false,
      );

      final expiredContent = RtcNotificationContent(
        senderTs: now.subtract(Duration(minutes: 5)),
        notificationType: RtcNotificationType.ring,
        lifetime: Duration(seconds: 30),
      );
      expect(
        expiredContent.isExpired(now.subtract(Duration(minutes: 5))),
        true,
      );
    });

    test('shouldNotifyUser validates notification rules', () {
      final userMentionedEvent = Event.fromJson(
        {
          'type': RtcNotificationContent.eventType,
          'sender': '@alice:example.com',
          'event_id': '\$event1',
          'origin_server_ts': now.millisecondsSinceEpoch,
          'content': {
            'sender_ts': now.millisecondsSinceEpoch,
            'notification_type': 'ring',
            'm.mentions': {
              'user_ids': ['@bob:example.com'],
            },
          },
        },
        room,
      );
      expect(
        RtcNotificationContent.fromEvent(userMentionedEvent).shouldNotifyUser(
          event: userMentionedEvent,
          currentUserId: '@bob:example.com',
        ),
        true,
      );
      expect(
        RtcNotificationContent.fromEvent(userMentionedEvent).shouldNotifyUser(
          event: userMentionedEvent,
          currentUserId: '@charlie:example.com',
        ),
        false,
      );

      final roomMentionEvent = Event.fromJson(
        {
          'type': RtcNotificationContent.eventType,
          'sender': '@alice:example.com',
          'event_id': '\$event2',
          'origin_server_ts': now.millisecondsSinceEpoch,
          'content': {
            'sender_ts': now.millisecondsSinceEpoch,
            'notification_type': 'notification',
            'm.mentions': {'room': true},
          },
        },
        room,
      );
      expect(
        RtcNotificationContent.fromEvent(roomMentionEvent).shouldNotifyUser(
          event: roomMentionEvent,
          currentUserId: '@anyone:example.com',
        ),
        true,
      );

      final expiredEvent = Event.fromJson(
        {
          'type': RtcNotificationContent.eventType,
          'sender': '@alice:example.com',
          'event_id': '\$event3',
          'origin_server_ts':
              now.subtract(Duration(minutes: 5)).millisecondsSinceEpoch,
          'content': {
            'sender_ts':
                now.subtract(Duration(minutes: 5)).millisecondsSinceEpoch,
            'notification_type': 'ring',
            'm.mentions': {
              'user_ids': ['@bob:example.com'],
            },
          },
        },
        room,
      );
      expect(
        RtcNotificationContent.fromEvent(expiredEvent).shouldNotifyUser(
          event: expiredEvent,
          currentUserId: '@bob:example.com',
        ),
        false,
      );
    });

    test('shouldNotifyUser handles isAlreadyRinging flag', () {
      final ringEvent = Event.fromJson(
        {
          'type': RtcNotificationContent.eventType,
          'sender': '@alice:example.com',
          'event_id': '\$event1',
          'origin_server_ts': now.millisecondsSinceEpoch,
          'content': {
            'sender_ts': now.millisecondsSinceEpoch,
            'notification_type': 'ring',
            'm.mentions': {
              'user_ids': ['@bob:example.com'],
            },
          },
        },
        room,
      );
      expect(
        RtcNotificationContent.fromEvent(ringEvent).shouldNotifyUser(
          event: ringEvent,
          currentUserId: '@bob:example.com',
          isAlreadyRinging: true,
        ),
        false,
      );

      final notificationEvent = Event.fromJson(
        {
          'type': RtcNotificationContent.eventType,
          'sender': '@alice:example.com',
          'event_id': '\$event2',
          'origin_server_ts': now.millisecondsSinceEpoch,
          'content': {
            'sender_ts': now.millisecondsSinceEpoch,
            'notification_type': 'notification',
            'm.mentions': {
              'user_ids': ['@bob:example.com'],
            },
          },
        },
        room,
      );
      expect(
        RtcNotificationContent.fromEvent(notificationEvent).shouldNotifyUser(
          event: notificationEvent,
          currentUserId: '@bob:example.com',
          isAlreadyRinging: true,
        ),
        true,
      );
    });
  });

  group('RtcNotificationEventExtension', () {
    test('isRtcNotificationEvent identifies event type', () {
      final rtcEvent = Event.fromJson(
        {
          'type': RtcNotificationContent.eventType,
          'sender': '@alice:example.com',
          'event_id': '\$event1',
          'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
          'content': {
            'sender_ts': DateTime.now().millisecondsSinceEpoch,
            'notification_type': 'ring',
          },
        },
        room,
      );
      expect(rtcEvent.isRtcNotificationEvent, true);

      final normalEvent = Event.fromJson(
        {
          'type': 'm.room.message',
          'sender': '@alice:example.com',
          'event_id': '\$event2',
          'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
          'content': {'body': 'Hello'},
        },
        room,
      );
      expect(normalEvent.isRtcNotificationEvent, false);
    });

    test('tryParseRtcNotificationContent handles valid and invalid events', () {
      final validEvent = Event.fromJson(
        {
          'type': RtcNotificationContent.eventType,
          'sender': '@alice:example.com',
          'event_id': '\$event1',
          'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
          'content': {
            'sender_ts': DateTime.now().millisecondsSinceEpoch,
            'notification_type': 'ring',
          },
        },
        room,
      );
      final content = validEvent.tryParseRtcNotificationContent();
      expect(content, isNotNull);
      expect(content!.notificationType, RtcNotificationType.ring);

      final wrongTypeEvent = Event.fromJson(
        {
          'type': 'm.room.message',
          'sender': '@alice:example.com',
          'event_id': '\$event2',
          'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
          'content': {'body': 'Hello'},
        },
        room,
      );
      expect(wrongTypeEvent.tryParseRtcNotificationContent(), null);

      final malformedEvent = Event.fromJson(
        {
          'type': RtcNotificationContent.eventType,
          'sender': '@alice:example.com',
          'event_id': '\$event3',
          'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
          'content': {
            'sender_ts': DateTime.now().millisecondsSinceEpoch,
            'notification_type': 'invalid',
          },
        },
        room,
      );
      expect(malformedEvent.tryParseRtcNotificationContent(), null);
    });
  });

  group('RtcNotificationRoomExtension', () {
    test('sendRtcNotification with various mention configurations', () async {
      FakeMatrixApi.calledEndpoints.clear();
      final userMentionEvent = await room.sendRtcNotification(
        type: RtcNotificationType.ring,
        userIds: ['@bob:example.com', '@charlie:example.com'],
      );
      expect(userMentionEvent, isNotNull);
      expect(userMentionEvent?.startsWith('\$event'), true);
      var entry = FakeMatrixApi.calledEndpoints.entries.firstWhere(
        (e) => e.key.contains('send/${RtcNotificationContent.eventType}/'),
      );
      var content = json.decode(entry.value.first);
      expect(content['notification_type'], 'ring');
      expect(
        content['m.mentions']['user_ids'],
        ['@bob:example.com', '@charlie:example.com'],
      );

      FakeMatrixApi.calledEndpoints.clear();
      final roomMentionEvent = await room.sendRtcNotification(
        type: RtcNotificationType.notification,
        mentionRoom: true,
      );
      expect(roomMentionEvent, isNotNull);
      entry = FakeMatrixApi.calledEndpoints.entries.firstWhere(
        (e) => e.key.contains('send/${RtcNotificationContent.eventType}/'),
      );
      content = json.decode(entry.value.first);
      expect(content['m.mentions'], {'room': true});

      FakeMatrixApi.calledEndpoints.clear();
      final combinedEvent = await room.sendRtcNotification(
        type: RtcNotificationType.notification,
        userIds: ['@alice:example.com'],
        mentionRoom: true,
      );
      expect(combinedEvent, isNotNull);
      entry = FakeMatrixApi.calledEndpoints.entries.firstWhere(
        (e) => e.key.contains('send/${RtcNotificationContent.eventType}/'),
      );
      content = json.decode(entry.value.first);
      expect(content['m.mentions'], {
        'room': true,
        'user_ids': ['@alice:example.com'],
      });
    });

    test('sendRtcNotification with member relation and custom lifetime',
        () async {
      FakeMatrixApi.calledEndpoints.clear();
      const memberEventId = '\$member123';
      final eventId = await room.sendRtcNotification(
        type: RtcNotificationType.ring,
        userIds: ['@bob:example.com'],
        memberEventId: memberEventId,
        lifetime: Duration(seconds: 60),
      );

      expect(eventId, isNotNull);
      final entry = FakeMatrixApi.calledEndpoints.entries.firstWhere(
        (e) => e.key.contains('send/${RtcNotificationContent.eventType}/'),
      );
      final content = json.decode(entry.value.first);
      expect(content['sender_ts'], isA<int>());
      expect(content['lifetime'], 60000);
      expect(content['m.relates_to'], {
        'rel_type': 'm.reference',
        'event_id': memberEventId,
      });
    });
  });
}
