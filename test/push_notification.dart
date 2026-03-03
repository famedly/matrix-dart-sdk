import 'dart:convert';

import 'package:test/test.dart';

import 'package:matrix/matrix.dart';

void main() {
  group('Push Notification', () {
    Logs().level = Level.error;

    const json = <String, dynamic>{
      'content': {
        'body': "I'm floating in a most peculiar way.",
        'msgtype': 'm.text',
      },
      'counts': {'missed_calls': 1, 'unread': 2},
      'devices': [
        {
          'app_id': 'org.matrix.matrixConsole.ios',
          'data': {},
          'pushkey': 'V2h5IG9uIGVhcnRoIGRpZCB5b3UgZGVjb2RlIHRoaXM/',
          'pushkey_ts': 12345678,
          'tweaks': {'sound': 'bing'},
        }
      ],
      'event_id': '\$3957tyerfgewrf384',
      'prio': 'high',
      'room_alias': '#exampleroom:matrix.org',
      'room_id': '!slw48wfj34rtnrf:example.com',
      'room_name': 'Mission Control',
      'sender': '@exampleuser:matrix.org',
      'sender_display_name': 'Major Tom',
      'type': 'm.room.message',
    };

    test('fromJson and toJson', () async {
      expect(PushNotification.fromJson(json).toJson(), json);
    });
    test('fromJson and toJson with String keys only', () async {
      final strJson =
          json.map((k, v) => MapEntry(k, v is String ? v : jsonEncode(v)));

      expect(PushNotification.fromJson(strJson).toJson(), json);
    });
  });
}
