// SPDX-FileCopyrightText: 2019-Present, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';
import 'package:test/test.dart';

const updates = {
  'empty': {
    'next_batch': 'blah',
    'account_data': {'events': []},
    'presences': {'events': []},
    'rooms': {'join': {}, 'leave': {}, 'invite': {}},
    'to_device': {'events': []},
  },
  'presence': {
    'next_batch': 'blah',
    'presence': {
      'events': [
        {
          'content': {
            'avatar_url': 'mxc://localhost:wefuiwegh8742w',
            'last_active_ago': 2478593,
            'presence': 'online',
            'currently_active': false,
            'status_msg': 'Making cupcakes',
          },
          'type': 'm.presence',
          'sender': '@example:localhost',
        },
      ],
    },
  },
  'account_data': {
    'next_batch': 'blah',
    'account_data': {
      'events': [
        {
          'type': 'blah',
          'content': {'beep': 'boop'},
        },
      ],
    },
  },
  'invite': {
    'next_batch': 'blah',
    'rooms': {
      'invite': {
        '!room': {
          'invite_state': {'events': []},
        },
      },
    },
  },
  'leave': {
    'next_batch': 'blah',
    'rooms': {
      'leave': {'!room': <String, dynamic>{}},
    },
  },
  'join': {
    'next_batch': 'blah',
    'rooms': {
      'join': {
        '!room': {
          'timeline': {'events': []},
          'state': {'events': []},
          'account_data': {'events': []},
          'ephemeral': {'events': []},
          'unread_notifications': <String, dynamic>{},
          'summary': <String, dynamic>{},
        },
      },
    },
  },
  'to_device': {
    'next_batch': 'blah',
    'to_device': {
      'events': [
        {
          'type': 'beep',
          'sender': '@example:localhost',
          'content': {'blah': 'blubb'},
        },
      ],
    },
  },
};

void testUpdates(bool Function(SyncUpdate s) test, Map<String, bool> expected) {
  for (final update in updates.entries) {
    final sync = SyncUpdate.fromJson(update.value);
    expect(test(sync), expected[update.key]);
  }
}

void main() {
  group('Sync Filters', () {
    Logs().level = Level.error;
    test('room update', () {
      bool testFn(SyncUpdate s) => s.hasRoomUpdate;
      final expected = {
        'empty': false,
        'presence': false,
        'account_data': true,
        'invite': true,
        'leave': true,
        'join': true,
        'to_device': true,
      };
      testUpdates(testFn, expected);
    });

    test('presence update', () {
      bool testFn(SyncUpdate s) => s.hasPresenceUpdate;
      final expected = {
        'empty': false,
        'presence': true,
        'account_data': false,
        'invite': false,
        'leave': false,
        'join': false,
        'to_device': false,
      };
      testUpdates(testFn, expected);
    });
  });
}
