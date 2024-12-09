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

import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import 'fake_client.dart';

void main() {
  /// All Tests related to the Event
  group('Event', () {
    Logs().level = Level.error;

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
      client = await getClient();
      room = Room(id: '!testroom:example.abc', client: client);
    });

    test('event_match rule', () async {
      final event = Event.fromJson(jsonObj, room);

      final override_ruleset = PushRuleSet(
        override: [
          PushRule(
            ruleId: 'my.rule',
            default$: false,
            enabled: true,
            actions: [
              'notify',
              {'set_tweak': 'highlight', 'value': true},
              {'set_tweak': 'sound', 'value': 'goose.wav'},
            ],
            conditions: [
              PushCondition(
                kind: 'event_match',
                pattern: 'fox',
                key: 'content.body',
              ),
            ],
          ),
        ],
      );
      final underride_ruleset = PushRuleSet(
        underride: [
          PushRule(
            ruleId: 'my.rule',
            default$: false,
            enabled: true,
            actions: [
              'notify',
              {'set_tweak': 'highlight', 'value': true},
              {'set_tweak': 'sound', 'value': 'goose.wav'},
            ],
            conditions: [
              PushCondition(
                kind: 'event_match',
                pattern: 'fox',
                key: 'content.body',
              ),
            ],
          ),
        ],
      );
      final content_ruleset = PushRuleSet(
        content: [
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
          ),
        ],
      );
      final room_ruleset = PushRuleSet(
        room: [
          PushRule(
            ruleId: room.id,
            default$: false,
            enabled: true,
            actions: [
              'notify',
              {'set_tweak': 'highlight', 'value': true},
              {'set_tweak': 'sound', 'value': 'goose.wav'},
            ],
          ),
        ],
      );
      final sender_ruleset = PushRuleSet(
        sender: [
          PushRule(
            ruleId: senderID,
            default$: false,
            enabled: true,
            actions: [
              'notify',
              {'set_tweak': 'highlight', 'value': true},
              {'set_tweak': 'sound', 'value': 'goose.wav'},
            ],
          ),
        ],
      );

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

      final override_ruleset2 = PushRuleSet(
        override: [
          PushRule(
            ruleId: 'my.rule',
            default$: false,
            enabled: true,
            actions: [
              'notify',
              {'set_tweak': 'highlight', 'value': true},
              {'set_tweak': 'sound', 'value': 'goose.wav'},
            ],
            conditions: [
              PushCondition(
                kind: 'event_match',
                pattern: senderID,
                key: 'sender',
              ),
            ],
          ),
        ],
      );

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

    test('invalid push condition', () async {
      final invalid_ruleset = PushRuleSet(
        override: [
          PushRule(
            ruleId: 'my.rule',
            default$: false,
            enabled: true,
            actions: [
              'notify',
              {'set_tweak': 'highlight', 'value': true},
              {'set_tweak': 'sound', 'value': 'goose.wav'},
            ],
            conditions: [
              PushCondition(
                kind: 'invalidcondition',
                pattern: 'fox',
                key: 'content.body',
              ),
            ],
          ),
        ],
      );

      expect(
        () => PushruleEvaluator.fromRuleset(invalid_ruleset),
        returnsNormally,
      );

      final evaluator = PushruleEvaluator.fromRuleset(invalid_ruleset);
      final event = Event.fromJson(jsonObj, room);
      final actions = evaluator.match(event);
      expect(actions.highlight, false);
      expect(actions.sound, null);
      expect(actions.notify, false);
    });

    test('match_display_name rule', () async {
      final event = Event.fromJson(jsonObj, room);
      (event.room.states[EventTypes.RoomMember] ??= {})[client.userID!] =
          Event.fromJson(
        {
          'type': EventTypes.RoomMember,
          'sender': senderID,
          'state_key': 'client.senderID',
          'content': {'displayname': 'Nico', 'membership': 'join'},
          'room_id': room.id,
          'origin_server_ts': 5,
        },
        room,
      );

      final ruleset = PushRuleSet(
        override: [
          PushRule(
            ruleId: 'my.rule',
            default$: false,
            enabled: true,
            actions: [
              'notify',
              {'set_tweak': 'highlight', 'value': true},
              {'set_tweak': 'sound', 'value': 'goose.wav'},
            ],
            conditions: [
              PushCondition(kind: 'contains_display_name'),
            ],
          ),
        ],
      );
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
          Event.fromJson(
        {
          'type': EventTypes.RoomMember,
          'sender': senderID,
          'state_key': 'client.senderID',
          'content': {'displayname': 'Nico', 'membership': 'join'},
          'room_id': room.id,
          'origin_server_ts': 5,
        },
        room,
      );

      final ruleset = PushRuleSet(
        override: [
          PushRule(
            ruleId: 'my.rule',
            default$: false,
            enabled: true,
            actions: [
              'notify',
              {'set_tweak': 'highlight', 'value': true},
              {'set_tweak': 'sound', 'value': 'goose.wav'},
            ],
            conditions: [
              PushCondition(kind: 'room_member_count', is$: '<5'),
            ],
          ),
        ],
      );
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
          Event.fromJson(
        {
          'type': EventTypes.RoomMember,
          'sender': senderID,
          'state_key': 'client.senderID',
          'content': {
            'notifications': {'broom': 20},
            'users': {senderID: 20},
          },
          'room_id': room.id,
          'origin_server_ts': 5,
        },
        room,
      );

      final ruleset = PushRuleSet(
        override: [
          PushRule(
            ruleId: 'my.rule',
            default$: false,
            enabled: true,
            actions: [
              'notify',
              {'set_tweak': 'highlight', 'value': true},
              {'set_tweak': 'sound', 'value': 'goose.wav'},
            ],
            conditions: [
              PushCondition(
                kind: 'sender_notification_permission',
                key: 'broom',
              ),
            ],
          ),
        ],
      );

      final evaluator = PushruleEvaluator.fromRuleset(ruleset);
      expect(evaluator.match(event).notify, true);

      event.senderId = '@a:b.c';
      expect(evaluator.match(event).notify, false);
    });

    test('invalid content rule', () async {
      final invalid_content_ruleset = PushRuleSet(
        content: [
          PushRule(
            ruleId: 'my.rule',
            default$: false,
            enabled: true,
            actions: [
              'notify',
              {'set_tweak': 'highlight', 'value': true},
              {'set_tweak': 'sound', 'value': 'goose.wav'},
            ],
            // pattern: 'fox', <- no pattern!
          ),
        ],
      );

      expect(
        () => PushruleEvaluator.fromRuleset(invalid_content_ruleset),
        returnsNormally,
      );

      final dendriteRuleset = PushRuleSet.fromJson(
        json.decode('''{
  "global": {
    "override": [
      {
        "rule_id": ".m.rule.master",
        "default": true,
        "enabled": false,
        "actions": [
          "dont_notify"
        ],
        "conditions": [],
        "pattern": ""
      },
      {
        "rule_id": ".m.rule.suppress_notices",
        "default": true,
        "enabled": true,
        "actions": [
          "dont_notify"
        ],
        "conditions": [
          {
            "kind": "event_match",
            "key": "content.msgtype",
            "pattern": "m.notice"
          }
        ],
        "pattern": ""
      },
      {
        "rule_id": ".m.rule.invite_for_me",
        "default": true,
        "enabled": true,
        "actions": [
          "notify",
          {
            "set_tweak": "sound",
            "value": "default"
          },
          {
            "set_tweak": "highlight",
            "value": false
          }
        ],
        "conditions": [
          {
            "kind": "event_match",
            "key": "type",
            "pattern": "m.room.member"
          },
          {
            "kind": "event_match",
            "key": "content.membership",
            "pattern": "invite"
          },
          {
            "kind": "event_match",
            "key": "state_key",
            "pattern": "@deepbluev7:dendrite.matrix.org"
          }
        ],
        "pattern": ""
      },
      {
        "rule_id": ".m.rule.member_event",
        "default": true,
        "enabled": true,
        "actions": [
          "dont_notify"
        ],
        "conditions": [
          {
            "kind": "event_match",
            "key": "type",
            "pattern": "m.room.member"
          }
        ],
        "pattern": ""
      },
      {
        "rule_id": ".m.rule.contains_display_name",
        "default": true,
        "enabled": true,
        "actions": [
          "notify",
          {
            "set_tweak": "sound",
            "value": "default"
          },
          {
            "set_tweak": "highlight",
            "value": true
          }
        ],
        "conditions": [
          {
            "kind": "contains_display_name"
          }
        ],
        "pattern": ""
      },
      {
        "rule_id": ".m.rule.tombstone",
        "default": true,
        "enabled": true,
        "actions": [
          "notify",
          {
            "set_tweak": "highlight",
            "value": false
          }
        ],
        "conditions": [
          {
            "kind": "event_match",
            "key": "type",
            "pattern": "m.room.tombstone"
          },
          {
            "kind": "event_match",
            "key": "state_key"
          }
        ],
        "pattern": ""
      },
      {
        "rule_id": ".m.rule.roomnotif",
        "default": true,
        "enabled": true,
        "actions": [
          "notify",
          {
            "set_tweak": "highlight",
            "value": false
          }
        ],
        "conditions": [
          {
            "kind": "event_match",
            "key": "content.body",
            "pattern": "@room"
          },
          {
            "kind": "sender_notification_permission",
            "key": "room"
          }
        ],
        "pattern": ""
      }
    ],
    "content": [
      {
        "rule_id": ".m.rule.contains_user_name",
        "default": true,
        "enabled": true,
        "actions": [
          "notify",
          {
            "set_tweak": "sound",
            "value": "default"
          },
          {
            "set_tweak": "highlight",
            "value": true
          }
        ],
        "conditions": null,
        "pattern": "deepbluev7"
      }
    ],
    "underride": [
      {
        "rule_id": ".m.rule.call",
        "default": true,
        "enabled": true,
        "actions": [
          "notify",
          {
            "set_tweak": "sound",
            "value": "ring"
          },
          {
            "set_tweak": "highlight",
            "value": false
          }
        ],
        "conditions": [
          {
            "kind": "event_match",
            "key": "type",
            "pattern": "m.call.invite"
          }
        ],
        "pattern": ""
      },
      {
        "rule_id": ".m.rule.encrypted_room_one_to_one",
        "default": true,
        "enabled": true,
        "actions": [
          "notify",
          {
            "set_tweak": "highlight",
            "value": false
          }
        ],
        "conditions": [
          {
            "kind": "room_member_count",
            "is": "2"
          },
          {
            "kind": "event_match",
            "key": "type",
            "pattern": "m.room.encrypted"
          }
        ],
        "pattern": ""
      },
      {
        "rule_id": ".m.rule.room_one_to_one",
        "default": true,
        "enabled": true,
        "actions": [
          "notify",
          {
            "set_tweak": "highlight",
            "value": false
          }
        ],
        "conditions": [
          {
            "kind": "room_member_count",
            "is": "2"
          },
          {
            "kind": "event_match",
            "key": "type",
            "pattern": "m.room.message"
          }
        ],
        "pattern": ""
      },
      {
        "rule_id": ".m.rule.message",
        "default": true,
        "enabled": true,
        "actions": [
          "notify"
        ],
        "conditions": [
          {
            "kind": "event_match",
            "key": "type",
            "pattern": "m.room.message"
          }
        ],
        "pattern": ""
      },
      {
        "rule_id": ".m.rule.encrypted",
        "default": true,
        "enabled": true,
        "actions": [
          "notify"
        ],
        "conditions": [
          {
            "kind": "event_match",
            "key": "type",
            "pattern": "m.room.encrypted"
          }
        ],
        "pattern": ""
      }
    ]
  }
}
'''),
      );
      expect(
        () => PushruleEvaluator.fromRuleset(dendriteRuleset),
        returnsNormally,
      );
    });
  });
}
