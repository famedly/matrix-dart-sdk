/*
 * Copyright (c) 2019 Zender & Kurtz GbR.
 *
 * Authors:
 *   Christian Pauly <krille@famedly.com>
 *   Marcel Radzio <mtrnord@famedly.com>
 *
 * This file is part of famedlysdk.
 *
 * famedlysdk is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * famedlysdk is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with famedlysdk.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'package:famedlysdk/src/utils/push_rules.dart';
import 'package:test/test.dart';

void main() {
  /// All Tests related to the MxContent
  group('PushRules', () {
    test('Create', () async {
      final json = {
        'global': {
          'content': [
            {
              'actions': [
                'notify',
                {'set_tweak': 'sound', 'value': 'default'},
                {'set_tweak': 'highlight'}
              ],
              'default': true,
              'enabled': true,
              'pattern': 'alice',
              'rule_id': '.m.rule.contains_user_name'
            }
          ],
          'override': [
            {
              'actions': ['dont_notify'],
              'conditions': [],
              'default': true,
              'enabled': false,
              'rule_id': '.m.rule.master'
            },
            {
              'actions': ['dont_notify'],
              'conditions': [
                {
                  'key': 'content.msgtype',
                  'kind': 'event_match',
                  'pattern': 'm.notice'
                }
              ],
              'default': true,
              'enabled': true,
              'rule_id': '.m.rule.suppress_notices'
            }
          ],
          'room': [],
          'sender': [],
          'underride': [
            {
              'actions': [
                'notify',
                {'set_tweak': 'sound', 'value': 'ring'},
                {'set_tweak': 'highlight', 'value': false}
              ],
              'conditions': [
                {
                  'key': 'type',
                  'kind': 'event_match',
                  'pattern': 'm.call.invite'
                }
              ],
              'default': true,
              'enabled': true,
              'rule_id': '.m.rule.call'
            },
            {
              'actions': [
                'notify',
                {'set_tweak': 'sound', 'value': 'default'},
                {'set_tweak': 'highlight'}
              ],
              'conditions': [
                {'kind': 'contains_display_name'}
              ],
              'default': true,
              'enabled': true,
              'rule_id': '.m.rule.contains_display_name'
            },
            {
              'actions': [
                'notify',
                {'set_tweak': 'sound', 'value': 'default'},
                {'set_tweak': 'highlight', 'value': false}
              ],
              'conditions': [
                {'kind': 'room_member_count', 'is': '2'},
                {
                  'kind': 'event_match',
                  'key': 'type',
                  'pattern': 'm.room.message'
                }
              ],
              'default': true,
              'enabled': true,
              'rule_id': '.m.rule.room_one_to_one'
            },
            {
              'actions': [
                'notify',
                {'set_tweak': 'sound', 'value': 'default'},
                {'set_tweak': 'highlight', 'value': false}
              ],
              'conditions': [
                {
                  'key': 'type',
                  'kind': 'event_match',
                  'pattern': 'm.room.member'
                },
                {
                  'key': 'content.membership',
                  'kind': 'event_match',
                  'pattern': 'invite'
                },
                {
                  'key': 'state_key',
                  'kind': 'event_match',
                  'pattern': '@alice:example.com'
                }
              ],
              'default': true,
              'enabled': true,
              'rule_id': '.m.rule.invite_for_me'
            },
            {
              'actions': [
                'notify',
                {'set_tweak': 'highlight', 'value': false}
              ],
              'conditions': [
                {
                  'key': 'type',
                  'kind': 'event_match',
                  'pattern': 'm.room.member'
                }
              ],
              'default': true,
              'enabled': true,
              'rule_id': '.m.rule.member_event'
            },
            {
              'actions': [
                'notify',
                {'set_tweak': 'highlight', 'value': false}
              ],
              'conditions': [
                {
                  'key': 'type',
                  'kind': 'event_match',
                  'pattern': 'm.room.message'
                }
              ],
              'default': true,
              'enabled': true,
              'rule_id': '.m.rule.message'
            }
          ]
        }
      };

      expect(PushRules.fromJson(json) != null, true);
    });
  });
}
