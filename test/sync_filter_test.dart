/*
 *   Ansible inventory script used at Famedly GmbH for managing many hosts
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

import 'package:famedlysdk/famedlysdk.dart';
import 'package:test/test.dart';

const UPDATES = {
  'empty': {
    'next_batch': 'blah',
    'account_data': {
      'events': [],
    },
    'presences': {
      'events': [],
    },
    'rooms': {
      'join': {},
      'leave': {},
      'invite': {},
    },
    'to_device': {
      'events': [],
    },
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
            'status_msg': 'Making cupcakes'
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
          'content': {
            'beep': 'boop',
          },
        },
      ],
    },
  },
  'invite': {
    'next_batch': 'blah',
    'rooms': {
      'invite': {
        '!room': {
          'invite_state': {
            'events': [],
          },
        },
      },
    },
  },
  'leave': {
    'next_batch': 'blah',
    'rooms': {
      'leave': {
        '!room': <String, dynamic>{},
      },
    },
  },
  'join': {
    'next_batch': 'blah',
    'rooms': {
      'join': {
        '!room': {
          'timeline': {
            'events': [],
          },
          'state': {
            'events': [],
          },
          'account_data': {
            'events': [],
          },
          'ephemeral': {
            'events': [],
          },
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
          'content': {
            'blah': 'blubb',
          },
        },
      ],
    },
  },
};

void testUpdates(bool Function(SyncUpdate s) test, Map<String, bool> expected) {
  for (final update in UPDATES.entries) {
    var sync = SyncUpdate.fromJson(update.value);
    expect(test(sync), expected[update.key]);
  }
}

void main() {
  group('Sync Filters', () {
    test('room update', () {
      var testFn = (SyncUpdate s) => s.hasRoomUpdate;
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
      var testFn = (SyncUpdate s) => s.hasPresenceUpdate;
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
