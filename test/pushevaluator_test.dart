/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020 Famedly GmbH
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
import 'fake_client.dart';

void main() {
  /// All Tests related to the Event
  group('Event', () {
    Logs().level = Level.error;
    var olmEnabled = true;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final id = '!4fsdfjisjf:server.abc';
    final senderID = '@alice:server.abc';
    final type = 'm.room.message';
    final msgtype = 'm.text';
    final body = 'Hello fox';
    final formatted_body = '<b>Hello</b> fox';

    final contentJson =
        '{"msgtype":"$msgtype","body":"$body","formatted_body":"$formatted_body","m.relates_to":{"m.in_reply_to":{"event_id":"\$1234:example.com"}}}';

    final jsonObj = <String, dynamic>{
      'event_id': id,
      'sender': senderID,
      'origin_server_ts': timestamp,
      'type': type,
      'room_id': '!testroom:example.abc',
      'status': EventStatus.synced.intValue,
      'content': json.decode(contentJson),
    };
    late Client client;
    late Room room;

    setUpAll(() async {
      try {
        await olm.init();
        olm.get_library_version();
      } catch (e) {
        olmEnabled = false;
        Logs().w('[LibOlm] Failed to load LibOlm', e);
      }
      Logs().i('[LibOlm] Enabled: $olmEnabled');
      client = await getClient();
      room = Room(id: '!testroom:example.abc', client: client);
    });

    test('event_match rule', () async {
      final event = Event.fromJson(jsonObj, room);

      final override_ruleset = PushRuleSet(override: [
        PushRule(ruleId: 'my.rule', default$: false, enabled: true, actions: [
          'notify',
          {'set_tweak': 'highlight', 'value': true},
          {'set_tweak': 'sound', 'value': 'goose.wav'},
        ], conditions: [
          PushCondition(
              kind: 'event_match', pattern: 'fox', key: 'content.body'),
        ])
      ]);
      final underride_ruleset = PushRuleSet(underride: [
        PushRule(ruleId: 'my.rule', default$: false, enabled: true, actions: [
          'notify',
          {'set_tweak': 'highlight', 'value': true},
          {'set_tweak': 'sound', 'value': 'goose.wav'},
        ], conditions: [
          PushCondition(
              kind: 'event_match', pattern: 'fox', key: 'content.body'),
        ])
      ]);
      final content_ruleset = PushRuleSet(content: [
        PushRule(
          ruleId: 'my.rule',
          default$: false,
          enabled: true,
          actions: [
            'notify',
            {'set_tweak': 'highlight', 'value': true},
            {'set_tweak': 'sound', 'value': 'goose.wav'},
          ],
          pattern: 'fox',
        )
      ]);
      final room_ruleset = PushRuleSet(room: [
        PushRule(
          ruleId: room.id,
          default$: false,
          enabled: true,
          actions: [
            'notify',
            {'set_tweak': 'highlight', 'value': true},
            {'set_tweak': 'sound', 'value': 'goose.wav'},
          ],
        )
      ]);
      final sender_ruleset = PushRuleSet(sender: [
        PushRule(
          ruleId: senderID,
          default$: false,
          enabled: true,
          actions: [
            'notify',
            {'set_tweak': 'highlight', 'value': true},
            {'set_tweak': 'sound', 'value': 'goose.wav'},
          ],
        )
      ]);

      void testMatch(PushRuleSet ruleset, Event event) {
        final evaluator = PushruleEvaluator.fromRuleset(ruleset);
        final actions = evaluator.match(event);
        expect(actions.notify, true);
        expect(actions.highlight, true);
        expect(actions.sound, 'goose.wav');
      }

      void testNotMatch(PushRuleSet ruleset, Event event) {
        final evaluator = PushruleEvaluator.fromRuleset(ruleset);
        final actions = evaluator.match(event);
        expect(actions.notify, false);
        expect(actions.highlight, false);
        expect(actions.sound, null);
      }

      testMatch(override_ruleset, event);
      testMatch(underride_ruleset, event);
      testMatch(content_ruleset, event);
      testMatch(room_ruleset, event);
      testMatch(sender_ruleset, event);

      event.content['body'] = 'FoX';
      testMatch(override_ruleset, event);
      testMatch(underride_ruleset, event);
      testMatch(content_ruleset, event);
      testMatch(room_ruleset, event);
      testMatch(sender_ruleset, event);

      event.content['body'] = '@FoX:';
      testMatch(override_ruleset, event);
      testMatch(underride_ruleset, event);
      testMatch(content_ruleset, event);
      testMatch(room_ruleset, event);
      testMatch(sender_ruleset, event);

      event.content['body'] = 'äFoXü';
      testMatch(override_ruleset, event);
      testMatch(underride_ruleset, event);
      testMatch(content_ruleset, event);
      testMatch(room_ruleset, event);
      testMatch(sender_ruleset, event);

      event.content['body'] = 'äFoXu';
      testNotMatch(override_ruleset, event);
      testNotMatch(underride_ruleset, event);
      testNotMatch(content_ruleset, event);
      testMatch(room_ruleset, event);
      testMatch(sender_ruleset, event);

      event.content['body'] = 'aFoXü';
      testNotMatch(override_ruleset, event);
      testNotMatch(underride_ruleset, event);
      testNotMatch(content_ruleset, event);
      testMatch(room_ruleset, event);
      testMatch(sender_ruleset, event);

      final override_ruleset2 = PushRuleSet(override: [
        PushRule(ruleId: 'my.rule', default$: false, enabled: true, actions: [
          'notify',
          {'set_tweak': 'highlight', 'value': true},
          {'set_tweak': 'sound', 'value': 'goose.wav'},
        ], conditions: [
          PushCondition(kind: 'event_match', pattern: senderID, key: 'sender'),
        ])
      ]);

      testMatch(override_ruleset2, event);
      event.senderId = '@nope:server.tld';
      testNotMatch(override_ruleset2, event);
      event.senderId = '${senderID}a';
      testNotMatch(override_ruleset2, event);
      event.senderId = 'a$senderID';
      testNotMatch(override_ruleset2, event);

      event.senderId = senderID;
      testMatch(override_ruleset2, event);
      override_ruleset2.override?[0].enabled = false;
      testNotMatch(override_ruleset2, event);
    });

    test('match_display_name rule', () async {
      final event = Event.fromJson(jsonObj, room);
      (event.room.states[EventTypes.RoomMember] ??= {})[client.userID!] =
          Event.fromJson({
        'type': EventTypes.RoomMember,
        'sender': senderID,
        'state_key': 'client.senderID',
        'content': {'displayname': 'Nico', 'membership': 'join'},
        'room_id': room.id,
        'origin_server_ts': 5,
      }, room);

      final ruleset = PushRuleSet(override: [
        PushRule(ruleId: 'my.rule', default$: false, enabled: true, actions: [
          'notify',
          {'set_tweak': 'highlight', 'value': true},
          {'set_tweak': 'sound', 'value': 'goose.wav'},
        ], conditions: [
          PushCondition(kind: 'contains_display_name'),
        ])
      ]);
      event.content['body'] = 'äNicoü';

      final evaluator = PushruleEvaluator.fromRuleset(ruleset);
      var actions = evaluator.match(event);
      expect(actions.notify, true);
      expect(actions.highlight, true);
      expect(actions.sound, 'goose.wav');

      event.content['body'] = 'äNicou';
      actions = evaluator.match(event);
      expect(actions.notify, false);
    });

    test('member_count rule', () async {
      final event = Event.fromJson(jsonObj, room);
      (event.room.states[EventTypes.RoomMember] ??= {})[client.userID!] =
          Event.fromJson({
        'type': EventTypes.RoomMember,
        'sender': senderID,
        'state_key': 'client.senderID',
        'content': {'displayname': 'Nico', 'membership': 'join'},
        'room_id': room.id,
        'origin_server_ts': 5,
      }, room);

      final ruleset = PushRuleSet(override: [
        PushRule(ruleId: 'my.rule', default$: false, enabled: true, actions: [
          'notify',
          {'set_tweak': 'highlight', 'value': true},
          {'set_tweak': 'sound', 'value': 'goose.wav'},
        ], conditions: [
          PushCondition(kind: 'room_member_count', is$: '<5'),
        ])
      ]);
      event.content['body'] = 'äNicoü';

      var evaluator = PushruleEvaluator.fromRuleset(ruleset);
      expect(evaluator.match(event).notify, true);

      ruleset.override?[0].conditions?[0].is$ = '<=0';
      evaluator = PushruleEvaluator.fromRuleset(ruleset);
      expect(evaluator.match(event).notify, false);

      ruleset.override?[0].conditions?[0].is$ = '<=1';
      evaluator = PushruleEvaluator.fromRuleset(ruleset);
      expect(evaluator.match(event).notify, true);

      ruleset.override?[0].conditions?[0].is$ = '>=1';
      evaluator = PushruleEvaluator.fromRuleset(ruleset);
      expect(evaluator.match(event).notify, true);

      ruleset.override?[0].conditions?[0].is$ = '>1';
      evaluator = PushruleEvaluator.fromRuleset(ruleset);
      expect(evaluator.match(event).notify, false);

      ruleset.override?[0].conditions?[0].is$ = '==1';
      evaluator = PushruleEvaluator.fromRuleset(ruleset);
      expect(evaluator.match(event).notify, true);

      ruleset.override?[0].conditions?[0].is$ = '1';
      evaluator = PushruleEvaluator.fromRuleset(ruleset);
      expect(evaluator.match(event).notify, true);
    });

    test('notification permissions rule', () async {
      final event = Event.fromJson(jsonObj, room);
      (event.room.states[EventTypes.RoomPowerLevels] ??= {})[''] =
          Event.fromJson({
        'type': EventTypes.RoomMember,
        'sender': senderID,
        'state_key': 'client.senderID',
        'content': {
          'notifications': {'broom': 20},
          'users': {senderID: 20},
        },
        'room_id': room.id,
        'origin_server_ts': 5,
      }, room);

      final ruleset = PushRuleSet(override: [
        PushRule(ruleId: 'my.rule', default$: false, enabled: true, actions: [
          'notify',
          {'set_tweak': 'highlight', 'value': true},
          {'set_tweak': 'sound', 'value': 'goose.wav'},
        ], conditions: [
          PushCondition(kind: 'sender_notification_permission', key: 'broom'),
        ])
      ]);

      final evaluator = PushruleEvaluator.fromRuleset(ruleset);
      expect(evaluator.match(event).notify, true);

      event.senderId = '@a:b.c';
      expect(evaluator.match(event).notify, false);
    });
  });
}
