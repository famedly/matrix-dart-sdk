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

import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:math';

import 'package:http/http.dart';

import 'package:matrix/matrix.dart' as sdk;
import 'package:matrix/matrix.dart';

T? tryCast<T>(dynamic object) => object is T ? object : null;

Map<String, dynamic> decodeJson(dynamic data) {
  if (data is String) {
    return json.decode(data);
  }
  if (data.isEmpty) {
    return <String, dynamic>{};
  }
  return data;
}

class FakeMatrixApi extends BaseClient {
  static String? expectedAccessToken;

  static Map<String, List<dynamic>> get calledEndpoints =>
      currentApi!._calledEndpoints;
  static int get eventCounter => currentApi!._eventCounter;
  static set eventCounter(int c) {
    currentApi!._eventCounter = c;
  }

  static set client(sdk.Client? c) {
    currentApi?._client = c;
  }

  static set failToDevice(bool fail) {
    currentApi?._failToDevice = fail;
  }

  static set trace(bool t) {
    currentApi?._trace = t;
  }

  final _calledEndpoints = <String, List<dynamic>>{};
  int _eventCounter = 0;
  sdk.Client? _client;
  bool _failToDevice = false;
  bool _trace = false;
  final _apiCallStream = StreamController<String>.broadcast();

  static FakeMatrixApi? currentApi;

  static Future<String> firstWhereValue(String value) {
    return firstWhere((v) => v == value);
  }

  static Future<String> firstWhere(bool Function(String element) test) {
    for (final e in currentApi!._calledEndpoints.entries) {
      if (e.value.isNotEmpty && test(e.key)) {
        return Future.value(e.key);
      }
    }

    final completer = Completer<String>();
    StreamSubscription<String>? sub;
    sub = currentApi!._apiCallStream.stream.listen((action) {
      if (test(action)) {
        sub?.cancel();
        completer.complete(action);
      }
    });
    return completer.future;
  }

  Set<String> servers = {
    'https://fakeserver.notexisting',
    'https://fakeserver.notexisting:1337',
    'https://fakeserverpriortoauthmedia.notexisting',
  };

  FutureOr<Response> mockIntercept(Request request) async {
    // Collect data from Request
    var action = request.url.path;
    if (request.url.path.contains('/_matrix')) {
      action =
          '${request.url.path.split('/_matrix').last}?${request.url.query}';
    }

    // ignore: avoid_print
    if (_trace) print('called $action');

    if (action.endsWith('?')) {
      action = action.substring(0, action.length - 1);
    }
    if (action.endsWith('?server_name')) {
      // This can be removed after matrix_api_lite is released with:
      // https://gitlab.com/famedly/libraries/matrix_api_lite/-/merge_requests/16
      action = action.substring(0, action.length - 12);
    }
    if (action.endsWith('/')) {
      action = action.substring(0, action.length - 1);
    }
    final method = request.method;
    final dynamic data =
        method == 'GET' ? request.url.queryParameters : request.body;
    dynamic res = {};
    var statusCode = 200;

    //print('\$method request to $action with Data: $data');

    if (!servers.contains(request.url.origin)) {
      return Response(
        '<html><head></head><body>Not found ${request.url.origin}...</body></html>',
        404,
      );
    }

    if (!{
          '/client/v3/refresh',
          '/client/v3/login',
          '/client/v3/register',
        }.contains(action) &&
        expectedAccessToken != null &&
        request.headers['Authorization'] != 'Bearer $expectedAccessToken') {
      return Response(
        jsonEncode({
          'errcode': 'M_UNKNOWN_TOKEN',
          'error': 'Soft logged out',
          'soft_logout': true,
        }),
        401,
      );
    }

    // Call API
    (_calledEndpoints[action] ??= <dynamic>[]).add(data);
    if (request.url.origin ==
            'https://fakeserverpriortoauthmedia.notexisting' &&
        action.contains('/client/versions')) {
      res = {
        'versions': [
          'r0.0.1',
          'ra.b.c',
          'v0.1',
          'v1.1',
          'v1.9',
          'v1.10.1',
        ],
        'unstable_features': {'m.lazy_load_members': true},
      };
    } else {
      final act = api[method]?[action];
      if (act != null) {
        res = act(data);
        if (res is Map && res.containsKey('errcode')) {
          if (res['errcode'] == 'M_NOT_FOUND') {
            statusCode = 404;
          } else {
            statusCode = 405;
          }
        }
      } else if (method == 'PUT' &&
          action.contains('/client/v3/sendToDevice/')) {
        res = {};
        if (_failToDevice) {
          statusCode = 500;
        }
      } else if (method == 'GET' &&
          action.contains('/client/v3/rooms/') &&
          action.contains('/state/m.room.member/') &&
          !action.endsWith('%40alicyy%3Aexample.com') &&
          !action.contains('%40getme')) {
        res = {'displayname': '', 'membership': 'ban'};
      } else if (method == 'PUT' &&
          action.contains(
            '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/',
          )) {
        res = {'event_id': '\$event${_eventCounter++}'};
      } else if (method == 'PUT' &&
          action.contains(
            '/client/v3/rooms/!1234%3AfakeServer.notExisting/state/',
          )) {
        res = {'event_id': '\$event${_eventCounter++}'};
      } else if (action.contains('/client/v3/sync')) {
        // Sync requests with timeout
        final timeout = request.url.queryParameters['timeout'];
        if (timeout != null && timeout != '0') {
          await Future.delayed(Duration(milliseconds: 50));
        }
        res = {
          // So that it is clear which sync we are processing prefix it with 'empty_'
          'next_batch': 'empty_${DateTime.now().millisecondsSinceEpoch}',
          // ensure we don't generate new keys for no reason
          'device_one_time_keys_count': {
            'curve25519': 10,
            'signed_curve25519': 100,
          },
        };
      } else if (method == 'PUT' &&
          _client != null &&
          action.contains('/account_data/') &&
          !action.contains('/rooms/')) {
        final type = Uri.decodeComponent(action.split('/').last);
        final syncUpdate = sdk.SyncUpdate(
          nextBatch: '',
          accountData: [sdk.BasicEvent(content: decodeJson(data), type: type)],
        );
        if (_client?.database != null) {
          await _client?.database?.transaction(() async {
            await _client?.handleSync(syncUpdate);
          });
        } else {
          await _client?.handleSync(syncUpdate);
        }
        res = {};
      } else if (method == 'PUT' &&
          _client != null &&
          action.contains('/account_data/') &&
          action.contains('/rooms/')) {
        final segments = action.split('/');
        final type = Uri.decodeComponent(segments.last);
        final roomId = Uri.decodeComponent(segments[segments.length - 3]);
        final syncUpdate = sdk.SyncUpdate(
          nextBatch: '',
          rooms: RoomsUpdate(
            join: {
              roomId: JoinedRoomUpdate(
                accountData: [
                  sdk.BasicEvent(
                    content: decodeJson(data),
                    type: type,
                  ),
                ],
              ),
            },
          ),
        );
        if (_client?.database != null) {
          await _client?.database?.transaction(() async {
            await _client?.handleSync(syncUpdate);
          });
        } else {
          await _client?.handleSync(syncUpdate);
        }
        res = {};
      } else {
        res = {
          'errcode': 'M_UNRECOGNIZED',
          'error': 'Unrecognized request: $action',
        };
        statusCode = 405;
      }
    }

    unawaited(
      Future.delayed(Duration(milliseconds: 1)).then((_) async {
        _apiCallStream.add(action);
      }),
    );
    return Response.bytes(utf8.encode(json.encode(res)), statusCode);
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final bodyStream = request.finalize();
    final bodyBytes = await bodyStream.toBytes();
    final r = Request(request.method, request.url)
      ..persistentConnection = request.persistentConnection
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..headers.addAll(request.headers)
      ..bodyBytes = bodyBytes
      ..finalize();

    final response = await mockIntercept(r);
    return StreamedResponse(
      ByteStream.fromBytes(response.bodyBytes),
      response.statusCode,
      contentLength: response.contentLength,
      request: request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  FakeMatrixApi() {
    currentApi = this;
    api['POST']?['/client/v3/keys/device_signing/upload'] = (var reqI) {
      if (_client != null) {
        final jsonBody = decodeJson(reqI);
        for (final keyType in {
          'master_key',
          'self_signing_key',
          'user_signing_key',
        }) {
          if (jsonBody[keyType] != null) {
            final key =
                sdk.CrossSigningKey.fromJson(jsonBody[keyType], _client!);
            _client!.userDeviceKeys[_client!.userID!]?.crossSigningKeys
                .removeWhere((k, v) => v.usage.contains(key.usage.first));
            _client!.userDeviceKeys[_client!.userID!]
                ?.crossSigningKeys[key.publicKey!] = key;
          }
        }
        // and generate a fake sync
        // ignore: discarded_futures
        _client!.handleSync(sdk.SyncUpdate(nextBatch: ''));
      }
      return {};
    };
  }

  static const Map<String, dynamic> messagesResponsePast = {
    'start': 't47429-4392820_219380_26003_2265',
    'end': 't47409-4357353_219380_26003_2265',
    'chunk': [
      {
        'content': {
          'body': 'This is an example text message',
          'msgtype': 'm.text',
          'format': 'org.matrix.custom.html',
          'formatted_body': '<b>This is an example text message</b>',
        },
        'type': 'm.room.message',
        'event_id': '3143273582443PhrSn:example.org',
        'room_id': '!1234:example.com',
        'sender': '@example:example.org',
        'origin_server_ts': 1432735824653,
        'unsigned': {'age': 1234},
      },
      {
        'content': {'name': 'The room name'},
        'type': 'm.room.name',
        'event_id': '2143273582443PhrSn:example.org',
        'room_id': '!1234:example.com',
        'sender': '@example:example.org',
        'origin_server_ts': 1432735824653,
        'unsigned': {'age': 1234},
        'state_key': '',
      },
      {
        'content': {
          'body': 'Gangnam Style',
          'url': 'mxc://example.org/a526eYUSFFxlgbQYZmo442',
          'info': {
            'thumbnail_url': 'mxc://example.org/FHyPlCeYUSFFxlgbQYZmoEoe',
            'thumbnail_info': {
              'mimetype': 'image/jpeg',
              'size': 46144,
              'w': 300,
              'h': 300,
            },
            'w': 480,
            'h': 320,
            'duration': 2140786,
            'size': 1563685,
            'mimetype': 'video/mp4',
          },
          'msgtype': 'm.video',
        },
        'type': 'm.room.message',
        'event_id': '1143273582443PhrSn:example.org',
        'room_id': '!1234:example.com',
        'sender': '@example:example.org',
        'origin_server_ts': 1432735824653,
        'unsigned': {'age': 1234},
      }
    ],
    'state': [],
  };
  static const Map<String, dynamic> messagesResponseFuture = {
    'start': 't456',
    'end': 't789',
    'chunk': [
      {
        'content': {
          'body': 'Gangnam Style',
          'url': 'mxc://example.org/a526eYUSFFxlgbQYZmo442',
          'info': {
            'thumbnail_url': 'mxc://example.org/FHyPlCeYUSFFxlgbQYZmoEoe',
            'thumbnail_info': {
              'mimetype': 'image/jpeg',
              'size': 46144,
              'w': 300,
              'h': 300,
            },
            'w': 480,
            'h': 320,
            'duration': 2140786,
            'size': 1563685,
            'mimetype': 'video/mp4',
          },
          'msgtype': 'm.video',
        },
        'type': 'm.room.message',
        'event_id': '1143273582443PhrSn:example.org',
        'room_id': '!1234:example.com',
        'sender': '@example:example.org',
        'origin_server_ts': 1432735824653,
        'unsigned': {'age': 1234},
      },
      {
        'content': {'name': 'The room name'},
        'type': 'm.room.name',
        'event_id': '2143273582443PhrSn:example.org',
        'room_id': '!1234:example.com',
        'sender': '@example:example.org',
        'origin_server_ts': 1432735824653,
        'unsigned': {'age': 1234},
        'state_key': '',
      },
      {
        'content': {
          'body': 'This is an example text message',
          'msgtype': 'm.text',
          'format': 'org.matrix.custom.html',
          'formatted_body': '<b>This is an example text message</b>',
        },
        'type': 'm.room.message',
        'event_id': '3143273582443PhrSn:example.org',
        'room_id': '!1234:example.com',
        'sender': '@example:example.org',
        'origin_server_ts': 1432735824653,
        'unsigned': {'age': 1234},
      }
    ],
    'state': [],
  };
  static const Map<String, dynamic> messagesResponseFutureEnd = {
    'start': 't789',
    'end': null,
    'chunk': [],
    'state': [],
  };

  static Map<String, dynamic> archivesMessageResponse = {
    'start': 't47429-4392820_219380_26003_2265',
    'end': 't47409-4357353_219380_26003_2265',
    'chunk': [
      {
        'content': {
          'body': 'This is an example text message',
          'msgtype': 'm.text',
          'format': 'org.matrix.custom.html',
          'formatted_body': '<b>This is an example text message</b>',
        },
        'type': 'm.room.message',
        'event_id': '3143273582443PhrSn:example.org',
        'room_id': '!5345234234:example.com',
        'sender': '@example:example.org',
        'origin_server_ts': 1432735824653,
        'unsigned': {'age': 1234},
      },
      {
        'content': {'name': 'The room name'},
        'type': 'm.room.name',
        'event_id': '2143273582443PhrSn:example.org',
        'room_id': '!5345234234:example.com',
        'sender': '@example:example.org',
        'origin_server_ts': 1432735824653,
        'unsigned': {'age': 1234},
        'state_key': '',
      },
      {
        'content': {
          'body': 'Gangnam Style',
          'url': 'mxc://example.org/a526eYUSFFxlgbQYZmo442',
          'info': {
            'thumbnail_url': 'mxc://example.org/FHyPlCeYUSFFxlgbQYZmoEoe',
            'thumbnail_info': {
              'mimetype': 'image/jpeg',
              'size': 46144,
              'w': 300,
              'h': 300,
            },
            'w': 480,
            'h': 320,
            'duration': 2140786,
            'size': 1563685,
            'mimetype': 'video/mp4',
          },
          'msgtype': 'm.video',
        },
        'type': 'm.room.message',
        'event_id': '1143273582466PhrSn:example.org',
        'room_id': '!5345234234:example.com',
        'sender': '@example:example.org',
        'origin_server_ts': 1432735824654,
        'unsigned': {'age': 1234},
      }
    ],
    'state': [],
  };

  static Map<String, dynamic> syncResponse = {
    'next_batch': Random().nextDouble().toString(),
    'rooms': {
      'join': {
        '!726s6s6q:example.com': {
          'summary': {
            'm.heroes': ['@alice:example.com'],
            'm.joined_member_count': 1,
            'm.invited_member_count': 0,
          },
          'unread_notifications': {
            'highlight_count': 2,
            'notification_count': 2,
          },
          'state': {
            'events': [
              {
                'sender': '@alice:example.com',
                'type': 'm.room.member',
                'state_key': '@alice:example.com',
                'content': {
                  'membership': 'join',
                  'avatar_url': 'mxc://example.org/SEsfnsuifSDFSSEF',
                  'displayname': 'Alice Margatroid',
                },
                'origin_server_ts': 1417731086795,
                'event_id': '66697273743031:example.com',
              },
              {
                'sender': '@alice:example.com',
                'type': 'm.room.canonical_alias',
                'content': {
                  'alias': '#famedlyContactDiscovery:fakeServer.notExisting',
                },
                'state_key': '',
                'origin_server_ts': 1417731086796,
                'event_id': '66697273743032:example.com',
              },
              {
                'sender': '@alice:example.com',
                'type': 'm.room.encryption',
                'state_key': '',
                'content': {'algorithm': AlgorithmTypes.megolmV1AesSha2},
                'origin_server_ts': 1417731086795,
                'event_id': '666972737430353:example.com',
              },
              {
                'content': {
                  'pinned': ['1234:bla'],
                },
                'type': 'm.room.pinned_events',
                'event_id': '21432735824443PhrSn:example.org',
                'room_id': '!1234:example.com',
                'sender': '@example:example.org',
                'origin_server_ts': 1432735824653,
                'unsigned': {'age': 1234},
                'state_key': '',
              },
            ],
          },
          'timeline': {
            'events': [
              {
                'sender': '@bob:example.com',
                'type': 'm.room.member',
                'state_key': '@bob:example.com',
                'content': {'membership': 'join'},
                'prev_content': {'membership': 'invite'},
                'origin_server_ts': 1417731086795,
                'event_id': '\$7365636s6r6432:example.com',
                'unsigned': {'foo': 'bar'},
              },
              {
                'sender': '@alice:example.com',
                'type': 'm.room.message',
                'content': {'body': 'I am a fish', 'msgtype': 'm.text'},
                'origin_server_ts': 1417731086797,
                'event_id': '74686972643033:example.com',
              }
            ],
            'limited': true,
            'prev_batch': 't34-23535_0_0',
          },
          'ephemeral': {
            'events': [
              {
                'type': 'm.typing',
                'content': {
                  'user_ids': ['@alice:example.com'],
                },
              },
              {
                'content': {
                  '\$7365636s6r6432:example.com': {
                    'm.read': {
                      '@alice:example.com': {'ts': 1436451550453},
                    },
                  },
                },
                'room_id': '!726s6s6q:example.com',
                'type': 'm.receipt',
              }
            ],
          },
          'account_data': {
            'events': [
              {
                'type': 'm.tag',
                'content': {
                  'tags': {
                    'work': {'order': 1},
                  },
                },
              },
              {
                'type': 'org.example.custom.room.config',
                'content': {'custom_config_key': 'custom_config_value'},
              }
            ],
          },
        },
        '!calls:example.com': {
          'state': {
            'events': [
              {
                'sender': '@test:fakeServer.notExisting',
                'type': 'm.room.member',
                'state_key': '@test:fakeServer.notExisting',
                'content': {
                  'membership': 'join',
                  'avatar_url': 'mxc://example.org/SEsfnsuifSDFSSEF',
                  'displayname': 'Test User',
                },
                'origin_server_ts': 1417731086795,
                'event_id': 'calls_1:example.com',
              },
              {
                'sender': '@alice:example.com',
                'type': 'm.room.member',
                'state_key': '@alice:example.com',
                'content': {
                  'membership': 'join',
                  'avatar_url': 'mxc://example.org/SEsfnsuifSDFSSEF',
                  'displayname': 'Alice Margatroid',
                },
                'origin_server_ts': 1417731086795,
                'event_id': 'calls_2:example.com',
              },
            ],
          },
        },
      },
      'invite': {
        '!696r7674:example.com': {
          'invite_state': {
            'events': [
              {
                'sender': '@alice:example.com',
                'type': 'm.room.name',
                'state_key': '',
                'content': {'name': 'My Room Name'},
              },
              {
                'sender': '@alice:example.com',
                'type': 'm.room.member',
                'state_key': '@bob:example.com',
                'content': {'membership': 'invite'},
              }
            ],
          },
        },
      },
      'leave': {
        '!726s6s6f:example.com': {
          'state': {
            'events': [
              {
                'sender': '@charley:example.com',
                'type': 'm.room.name',
                'state_key': '',
                'content': {'name': 'left room'},
                'origin_server_ts': 1417731086795,
                'event_id': '66697273743031:example.com',
              },
            ],
          },
          'timeline': {
            'events': [
              {
                'sender': '@bob:example.com',
                'type': 'm.room.message',
                'content': {'text': 'Hallo'},
                'origin_server_ts': 1417731086795,
                'event_id': '7365636s6r64300:example.com',
                'unsigned': {'foo': 'bar'},
              },
            ],
            'limited': true,
            'prev_batch': 't34-23535_0_0',
          },
          'account_data': {
            'events': [
              {
                'type': 'm.tag',
                'content': {
                  'tags': {
                    'work': {'order': 1},
                  },
                },
              },
              {
                'type': 'org.example.custom.room.config',
                'content': {'custom_config_key': 'custom_config_value'},
              }
            ],
          },
        },
      },
    },
    'presence': {
      'events': [
        {
          'sender': '@alice:example.com',
          'type': 'm.presence',
          'content': {'presence': 'online'},
        }
      ],
    },
    'account_data': {
      'events': [
        {
          'content': {
            'global': {
              'content': [
                {
                  'actions': [
                    'notify',
                    {'set_tweak': 'sound', 'value': 'default'},
                    {'set_tweak': 'highlight'},
                  ],
                  'default': true,
                  'enabled': true,
                  'pattern': 'alice',
                  'rule_id': '.m.rule.contains_user_name',
                }
              ],
              'override': [
                {
                  'actions': ['dont_notify'],
                  'conditions': [],
                  'default': true,
                  'enabled': false,
                  'rule_id': '.m.rule.master',
                },
                {
                  'actions': ['dont_notify'],
                  'conditions': [
                    {
                      'key': 'content.msgtype',
                      'kind': 'event_match',
                      'pattern': 'm.notice',
                    }
                  ],
                  'default': true,
                  'enabled': true,
                  'rule_id': '.m.rule.suppress_notices',
                }
              ],
              'room': [
                {
                  'actions': ['dont_notify'],
                  'conditions': [
                    {
                      'key': 'room_id',
                      'kind': 'event_match',
                      'pattern': '!localpart:server.abc',
                    }
                  ],
                  'default': true,
                  'enabled': true,
                  'rule_id': '!localpart:server.abc',
                }
              ],
              'sender': [],
              'underride': [
                {
                  'actions': [
                    'notify',
                    {'set_tweak': 'sound', 'value': 'ring'},
                    {'set_tweak': 'highlight', 'value': false},
                  ],
                  'conditions': [
                    {
                      'key': 'type',
                      'kind': 'event_match',
                      'pattern': 'm.call.invite',
                    }
                  ],
                  'default': true,
                  'enabled': true,
                  'rule_id': '.m.rule.call',
                },
                {
                  'actions': [
                    'notify',
                    {'set_tweak': 'sound', 'value': 'default'},
                    {'set_tweak': 'highlight'},
                  ],
                  'conditions': [
                    {'kind': 'contains_display_name'},
                  ],
                  'default': true,
                  'enabled': true,
                  'rule_id': '.m.rule.contains_display_name',
                },
                {
                  'actions': [
                    'notify',
                    {'set_tweak': 'sound', 'value': 'default'},
                    {'set_tweak': 'highlight', 'value': false},
                  ],
                  'conditions': [
                    {'is': '2', 'kind': 'room_member_count'},
                    {
                      'key': 'type',
                      'kind': 'event_match',
                      'pattern': 'm.room.message',
                    }
                  ],
                  'default': true,
                  'enabled': true,
                  'rule_id': '.m.rule.room_one_to_one',
                },
                {
                  'actions': [
                    'notify',
                    {'set_tweak': 'sound', 'value': 'default'},
                    {'set_tweak': 'highlight', 'value': false},
                  ],
                  'conditions': [
                    {
                      'key': 'type',
                      'kind': 'event_match',
                      'pattern': 'm.room.member',
                    },
                    {
                      'key': 'content.membership',
                      'kind': 'event_match',
                      'pattern': 'invite',
                    },
                    {
                      'key': 'state_key',
                      'kind': 'event_match',
                      'pattern': '@alice:example.com',
                    }
                  ],
                  'default': true,
                  'enabled': true,
                  'rule_id': '.m.rule.invite_for_me',
                },
                {
                  'actions': [
                    'notify',
                    {'set_tweak': 'highlight', 'value': false},
                  ],
                  'conditions': [
                    {
                      'key': 'type',
                      'kind': 'event_match',
                      'pattern': 'm.room.member',
                    }
                  ],
                  'default': true,
                  'enabled': true,
                  'rule_id': '.m.rule.member_event',
                },
                {
                  'actions': [
                    'notify',
                    {'set_tweak': 'highlight', 'value': false},
                  ],
                  'conditions': [
                    {
                      'key': 'type',
                      'kind': 'event_match',
                      'pattern': 'm.room.message',
                    }
                  ],
                  'default': true,
                  'enabled': true,
                  'rule_id': '.m.rule.message',
                }
              ],
            },
          },
          'type': 'm.push_rules',
        },
        {
          'type': 'org.example.custom.config',
          'content': {'custom_config_key': 'custom_config_value'},
        },
        {
          'content': {
            '@bob:example.com': [
              '!726s6s6q:example.com',
              '!hgfedcba:example.com',
            ],
          },
          'type': 'm.direct',
        },
        {
          'type': EventTypes.SecretStorageDefaultKey,
          'content': {'key': '0FajDWYaM6wQ4O60OZnLvwZfsBNu4Bu3'},
        },
        {
          'type': 'm.secret_storage.key.0FajDWYaM6wQ4O60OZnLvwZfsBNu4Bu3',
          'content': {
            'algorithm': AlgorithmTypes.secretStorageV1AesHmcSha2,
            'passphrase': {
              'algorithm': AlgorithmTypes.pbkdf2,
              'iterations': 500000,
              'salt': 'F4jJ80mr0Fc8mRwU9JgA3lQDyjPuZXQL',
            },
            'iv': 'HjbTgIoQH2pI7jQo19NUzA==',
            'mac': 'QbJjQzDnAggU0cM4RBnDxw2XyarRGjdahcKukP9xVlk=',
          },
        },
        {
          'type': 'm.cross_signing.master',
          'content': {
            'encrypted': {
              '0FajDWYaM6wQ4O60OZnLvwZfsBNu4Bu3': {
                'iv': 'eIb2IITxtmcq+1TrT8D5eQ==',
                'ciphertext':
                    'lWRTPo5qxf4LAVwVPzGHOyMcP181n7bb9/B0lvkLDC2Oy4DvAL0eLx2x3bY=',
                'mac': 'Ynx89tIxPkx0o6ljMgxszww17JOgB4tg4etmNnMC9XI=',
              },
            },
          },
        },
        {
          'type': EventTypes.CrossSigningSelfSigning,
          'content': {
            'encrypted': {
              '0FajDWYaM6wQ4O60OZnLvwZfsBNu4Bu3': {
                'iv': 'YqU2XIjYulYZl+bkZtGgVw==',
                'ciphertext':
                    'kM2TSoy/jR/4d357ZoRPbpPypxQl6XRLo3FsEXz+f7vIOp82GeRp28RYb3k=',
                'mac': 'F+DZa5tAFmWsYSryw5EuEpzTmmABRab4GETkM85bGGo=',
              },
            },
          },
        },
        {
          'type': EventTypes.CrossSigningUserSigning,
          'content': {
            'encrypted': {
              '0FajDWYaM6wQ4O60OZnLvwZfsBNu4Bu3': {
                'iv': 'D7AM3LXFu7ZlyGOkR+OeqQ==',
                'ciphertext':
                    'bYA2+OMgsO6QB1E31aY+ESAWrT0fUBTXqajy4qmL7bVDSZY4Uj64EXNbHuA=',
                'mac': 'j2UtyPo/UBSoiaQCWfzCiRZXp3IRt0ZZujuXgUMjnw4=',
              },
            },
          },
        },
        {
          'type': EventTypes.MegolmBackup,
          'content': {
            'encrypted': {
              '0FajDWYaM6wQ4O60OZnLvwZfsBNu4Bu3': {
                'iv': 'cL/0MJZaiEd3fNU+I9oJrw==',
                'ciphertext':
                    'WL73Pzdk5wZdaaSpaeRH0uZYKcxkuV8IS6Qa2FEfA1+vMeRLuHcWlXbMX0w=',
                'mac': '+xozp909S6oDX8KRV8D8ZFVRyh7eEYQpPP76f+DOsnw=',
              },
            },
          },
        },
        {
          'type': 'io.element.recent_emoji',
          'content': {
            'recent_emoji': [
              ['👍️', 1],
              ['🖇️', 0],
              ['🙃', 'error'],
              [null, null],
              [1, ''],
            ],
          },
        }
      ],
    },
    'to_device': {
      'events': [
        {
          'sender': '@alice:example.com',
          'type': 'm.new_device',
          'content': {
            'device_id': 'XYZABCDE',
            'rooms': ['!726s6s6q:example.com'],
          },
        },
//        {
//          'sender': '@othertest:fakeServer.notExisting',
//          'content': {
//            'algorithm': AlgorithmTypes.megolmV1AesSha2,
//            'room_id': '!726s6s6q:example.com',
//            'session_id': 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU',
//            'session_key':
//                'AgAAAAAQcQ6XrFJk6Prm8FikZDqfry/NbDz8Xw7T6e+/9Yf/q3YHIPEQlzv7IZMNcYb51ifkRzFejVvtphS7wwG2FaXIp4XS2obla14iKISR0X74ugB2vyb1AydIHE/zbBQ1ic5s3kgjMFlWpu/S3FQCnCrv+DPFGEt3ERGWxIl3Bl5X53IjPyVkz65oljz2TZESwz0GH/QFvyOOm8ci0q/gceaF3S7Dmafg3dwTKYwcA5xkcc+BLyrLRzB6Hn+oMAqSNSscnm4mTeT5zYibIhrzqyUTMWr32spFtI9dNR/RFSzfCw'
//          },
//          'type': 'm.room_key'
//        },
        {
          // this is the commented out m.room_key event - only encrypted
          'sender': '@othertest:fakeServer.notExisting',
          'content': {
            'algorithm': AlgorithmTypes.olmV1Curve25519AesSha2,
            'sender_key': 'JBG7ZaPn54OBC7TuIEiylW3BZ+7WcGQhFBPB9pogbAg',
            'ciphertext': {
              '7rvl3jORJkBiK4XX1e5TnGnqz068XfYJ0W++Ml63rgk': {
                'type': 0,
                'body':
                    'Awogyh7K4iLUQjcOxIfi7q7LhBBqv9w0mQ6JI9+U9tv7iF4SIHC6xb5YFWf9voRnmDBbd+0vxD/xDlVNRDlPIKliLGkYGiAkEbtlo+fng4ELtO4gSLKVbcFn7tZwZCEUE8H2miBsCCKABgMKIFrKDJwB7gM3lXPt9yVoh6gQksafKt7VFCNRN5KLKqsDEAAi0AX5EfTV7jJ1ZWAbxftjoSN6kCVIxzGclbyg1HjchmNCX7nxNCHWl+q5ZgqHYZVu2n2mCVmIaKD0kvoEZeY3tV1Itb6zf67BLaU0qgW/QzHCHg5a44tNLjucvL2mumHjIG8k0BY2uh+52HeiMCvSOvtDwHg7nzCASGdqPVCj9Kzw6z7F6nL4e3mYim8zvJd7f+mD9z3ARrypUOLGkTGYbB2PQOovf0Do8WzcaRzfaUCnuu/YVZWKK7DPgG8uhw/TjR6XtraAKZysF+4DJYMG9SQWx558r6s7Z5EUOF5CU2M35w1t1Xxllb3vrS83dtf9LPCrBhLsEBeYEUBE2+bTBfl0BDKqLiB0Cc0N0ixOcHIt6e40wAvW622/gMgHlpNSx8xG12u0s6h6EMWdCXXLWd9fy2q6glFUHvA67A35q7O+M8DVml7Y9xG55Y3DHkMDc9cwgwFkBDCAYQe6pQF1nlKytcVCGREpBs/gq69gHAStMQ8WEg38Lf8u8eBr2DFexrN4U+QAk+S//P3fJgf0bQx/Eosx4fvWSz9En41iC+ADCsWQpMbwHn4JWvtAbn3oW0XmL/OgThTkJMLiCymduYAa1Hnt7a3tP0KTL2/x11F02ggQHL28cCjq5W4zUGjWjl5wo2PsKB6t8aAvMg2ujGD2rCjb4yrv5VIzAKMOZLyj7K0vSK9gwDLQ/4vq+QnKUBG5zrcOze0hX+kz2909/tmAdeCH61Ypw7gbPUJAKnmKYUiB/UgwkJvzMJSsk/SEs5SXosHDI+HsJHJp4Mp4iKD0xRMst+8f9aTjaWwh8ZvELE1ZOhhCbF3RXhxi3x2Nu8ORIz+vhEQ1NOlMc7UIo98Fk/96T36vL/fviowT4C/0AlaapZDJBmKwhmwqisMjY2n1vY29oM2p5BzY1iwP7q9BYdRFst6xwo57TNSuRwQw7IhFsf0k+ABuPEZy5xB5nPHyIRTf/pr3Hw',
              },
            },
          },
          'type': 'm.room.encrypted',
        },
      ],
    },
    'device_lists': {
      'changed': [
        '@alice:example.com',
      ],
      'left': [
        '@bob:example.com',
      ],
    },
    'device_one_time_keys_count': {'curve25519': 10, 'signed_curve25519': 100},
  };

  static Map<String, dynamic> archiveSyncResponse = {
    'next_batch': Random().nextDouble().toString(),
    'presence': {'events': []},
    'account_data': {'events': []},
    'to_device': {'events': []},
    'rooms': {
      'join': {},
      'invite': {},
      'leave': {
        '!5345234234:example.com': {
          'timeline': {
            'events': [
              {
                'content': {
                  'body': 'This is a second text example message',
                  'msgtype': 'm.text',
                  'format': 'org.matrix.custom.html',
                  'formatted_body':
                      '<b>This is a second text example message</b>',
                },
                'type': 'm.room.message',
                'event_id': '143274597446PhrSn:example.org',
                'room_id': '!5345234234:example.com',
                'sender': '@example:example.org',
                'origin_server_ts': 1432735824654,
                'unsigned': {'age': 1234},
              },
              {
                'content': {
                  'body': 'This is a first text example message',
                  'msgtype': 'm.text',
                  'format': 'org.matrix.custom.html',
                  'formatted_body':
                      '<b>This is a first text example message</b>',
                },
                'type': 'm.room.message',
                'event_id': '143274597443PhrSn:example.org',
                'room_id': '!5345234234:example.com',
                'sender': '@example:example.org',
                'origin_server_ts': 1432735824653,
                'unsigned': {'age': 1234},
              }
            ],
            'prev_batch': 't_1234a',
          },
          'state': {
            'events': [
              {
                'content': {'name': 'The room name'},
                'type': 'm.room.name',
                'event_id': '2143273582443PhrSn:example.org',
                'room_id': '!5345234234:example.com',
                'sender': '@example:example.org',
                'origin_server_ts': 1432735824653,
                'unsigned': {'age': 1234},
                'state_key': '',
              },
            ],
          },
          'account_data': {
            'events': [
              {
                'type': 'test.type.data',
                'content': {'foo': 'bar'},
              },
            ],
          },
        },
        '!5345234235:example.com': {
          'timeline': {'events': []},
          'state': {
            'events': [
              {
                'content': {'name': 'The room name 2'},
                'type': 'm.room.name',
                'event_id': '2143273582443PhrSn:example.org',
                'room_id': '!5345234235:example.com',
                'sender': '@example:example.org',
                'origin_server_ts': 1432735824653,
                'unsigned': {'age': 1234},
                'state_key': '',
              },
            ],
          },
          'prev_batch': 't_1234b',
        },
      },
    },
  };

  Map<String, Map<String, dynamic>> api = {
    'GET': {
      '/path/to/auth/error': (var req) => {
            'errcode': 'M_FORBIDDEN',
            'error': 'Blabla',
          },
      '/media/v3/preview_url?url=https%3A%2F%2Fmatrix.org&ts=10': (var req) => {
            'og:title': 'Matrix Blog Post',
            'og:description': 'This is a really cool blog post from matrix.org',
            'og:image': 'mxc://example.com/ascERGshawAWawugaAcauga',
            'og:image:type': 'image/png',
            'og:image:height': 48,
            'og:image:width': 48,
            'matrix:image:size': 102400,
          },
      '/client/v1/media/preview_url?url=https%3A%2F%2Fmatrix.org&ts=10':
          (var req) => {
                'og:title': 'Matrix Blog Post',
                'og:description':
                    'This is a really cool blog post from matrix.org',
                'og:image': 'mxc://example.com/ascERGshawAWawugaAcauga',
                'og:image:type': 'image/png',
                'og:image:height': 48,
                'og:image:width': 48,
                'matrix:image:size': 102400,
              },
      '/media/v3/config': (var req) => {'m.upload.size': 50000000},
      '/client/v1/media/config': (var req) => {'m.upload.size': 50000000},
      '/.well-known/matrix/client': (var req) => {
            'm.homeserver': {'base_url': 'https://fakeserver.notexisting'},
            'm.identity_server': {'base_url': 'https://identity.example.com'},
            'org.example.custom.property': {
              'app_url': 'https://custom.app.example.org',
            },
          },
      '/client/v3/user/%40alice%3Aexample.com/rooms/!localpart%3Aexample.com/tags':
          (var req) => {
                'tags': {
                  'm.favourite': {'order': 0.1},
                  'u.Work': {'order': 0.7},
                  'u.Customers': {},
                },
              },
      '/client/v3/events?from=1234&timeout=10&roomId=%211234': (var req) => {
            'start': 's3456_9_0',
            'end': 's3457_9_0',
            'chunk': [
              {
                'content': {
                  'body': 'This is an example text message',
                  'msgtype': 'm.text',
                  'format': 'org.matrix.custom.html',
                  'formatted_body': '<b>This is an example text message</b>',
                },
                'type': 'm.room.message',
                'event_id': '\$143273582443PhrSn:example.org',
                'room_id': '!somewhere:over.the.rainbow',
                'sender': '@example:example.org',
                'origin_server_ts': 1432735824653,
                'unsigned': {'age': 1234},
              }
            ],
          },
      '/client/v3/thirdparty/location?alias=1234': (var req) => [
            {
              'alias': '#freenode_#matrix:matrix.org',
              'protocol': 'irc',
              'fields': {'network': 'freenode', 'channel': '#matrix'},
            }
          ],
      '/client/v3/thirdparty/location/irc': (var req) => [
            {
              'alias': '#freenode_#matrix:matrix.org',
              'protocol': 'irc',
              'fields': {'network': 'freenode', 'channel': '#matrix'},
            }
          ],
      '/client/v3/thirdparty/user/irc': (var req) => [
            {
              'userid': '@_gitter_jim:matrix.org',
              'protocol': 'gitter',
              'fields': {'user': 'jim'},
            }
          ],
      '/client/v3/thirdparty/user?userid=1234': (var req) => [
            {
              'userid': '@_gitter_jim:matrix.org',
              'protocol': 'gitter',
              'fields': {'user': 'jim'},
            }
          ],
      '/client/v3/thirdparty/protocol/irc': (var req) => {
            'user_fields': ['network', 'nickname'],
            'location_fields': ['network', 'channel'],
            'icon': 'mxc://example.org/aBcDeFgH',
            'field_types': {
              'network': {
                'regexp': '([a-z0-9]+\\.)*[a-z0-9]+',
                'placeholder': 'irc.example.org',
              },
              'nickname': {'regexp': '[^\\s#]+', 'placeholder': 'username'},
              'channel': {'regexp': '#[^\\s]+', 'placeholder': '#foobar'},
            },
            'instances': [
              {
                'desc': 'Freenode',
                'icon': 'mxc://example.org/JkLmNoPq',
                'fields': {'network': 'freenode'},
                'network_id': 'freenode',
              }
            ],
          },
      '/client/v3/thirdparty/protocols': (var req) => {
            'irc': {
              'user_fields': ['network', 'nickname'],
              'location_fields': ['network', 'channel'],
              'icon': 'mxc://example.org/aBcDeFgH',
              'field_types': {
                'network': {
                  'regexp': '([a-z0-9]+\\.)*[a-z0-9]+',
                  'placeholder': 'irc.example.org',
                },
                'nickname': {'regexp': '[^\\s]+', 'placeholder': 'username'},
                'channel': {'regexp': '#[^\\s]+', 'placeholder': '#foobar'},
              },
              'instances': [
                {
                  'network_id': 'freenode',
                  'desc': 'Freenode',
                  'icon': 'mxc://example.org/JkLmNoPq',
                  'fields': {'network': 'freenode.net'},
                }
              ],
            },
            'gitter': {
              'user_fields': ['username'],
              'location_fields': ['room'],
              'icon': 'mxc://example.org/aBcDeFgH',
              'field_types': {
                'username': {'regexp': '@[^\\s]+', 'placeholder': '@username'},
                'room': {
                  'regexp': '[^\\s]+\\/[^\\s]+',
                  'placeholder': 'matrix-org/matrix-doc',
                },
              },
              'instances': [
                {
                  'network_id': 'gitter',
                  'desc': 'Gitter',
                  'icon': 'mxc://example.org/zXyWvUt',
                  'fields': {},
                }
              ],
            },
          },
      '/client/v3/account/whoami': (var req) =>
          {'user_id': 'alice@example.com'},
      '/client/v3/capabilities': (var req) => {
            'capabilities': {
              'm.change_password': {'enabled': false},
              'm.room_versions': {
                'default': '1',
                'available': {
                  '1': 'stable',
                  '2': 'stable',
                  '3': 'unstable',
                  'test-version': 'unstable',
                },
              },
              'com.example.custom.ratelimit': {'max_requests_per_hour': 600},
            },
          },
      '/client/v3/rooms/1234/context/1234?filter=%7B%7D&limit=10': (var req) =>
          {
            'end': 't29-57_2_0_2',
            'events_after': [
              {
                'content': {
                  'body': 'This is an example text message',
                  'msgtype': 'm.text',
                  'format': 'org.matrix.custom.html',
                  'formatted_body': '<b>This is an example text message</b>',
                },
                'type': 'm.room.message',
                'event_id': '\$143273582443PhrSn:example.org',
                'room_id': '!636q39766251:example.com',
                'sender': '@example:example.org',
                'origin_server_ts': 1432735824653,
                'unsigned': {'age': 1234},
              }
            ],
            'event': {
              'content': {
                'body': 'filename.jpg',
                'info': {
                  'h': 398,
                  'w': 394,
                  'mimetype': 'image/jpeg',
                  'size': 31037,
                },
                'url': 'mxc://example.org/JWEIFJgwEIhweiWJE',
                'msgtype': 'm.image',
              },
              'type': 'm.room.message',
              'event_id': '\$f3h4d129462ha:example.com',
              'room_id': '!636q39766251:example.com',
              'sender': '@example:example.org',
              'origin_server_ts': 1432735824653,
              'unsigned': {'age': 1234},
            },
            'events_before': [
              {
                'content': {
                  'body': 'something-important.doc',
                  'filename': 'something-important.doc',
                  'info': {'mimetype': 'application/msword', 'size': 46144},
                  'msgtype': 'm.file',
                  'url': 'mxc://example.org/FHyPlCeYUSFFxlgbQYZmoEoe',
                },
                'type': 'm.room.message',
                'event_id': '\$143273582443PhrSn:example.org',
                'room_id': '!636q39766251:example.com',
                'sender': '@example:example.org',
                'origin_server_ts': 1432735824653,
                'unsigned': {'age': 1234},
              }
            ],
            'start': 't27-54_2_0_2',
            'state': [
              {
                'content': {
                  'creator': '@example:example.org',
                  'room_version': '1',
                  'm.federate': true,
                  'predecessor': {
                    'event_id': '\$something:example.org',
                    'room_id': '!oldroom:example.org',
                  },
                },
                'type': 'm.room.create',
                'event_id': '\$143273582443PhrSn:example.org',
                'room_id': '!636q39766251:example.com',
                'sender': '@example:example.org',
                'origin_server_ts': 1432735824653,
                'unsigned': {'age': 1234},
                'state_key': '',
              },
              {
                'content': {
                  'membership': 'join',
                  'avatar_url': 'mxc://example.org/SEsfnsuifSDFSSEF',
                  'displayname': 'Alice Margatroid',
                },
                'type': 'm.room.member',
                'event_id': '\$143273582443PhrSn:example.org',
                'room_id': '!636q39766251:example.com',
                'sender': '@example:example.org',
                'origin_server_ts': 1432735824653,
                'unsigned': {'age': 1234},
                'state_key': '@alice:example.org',
              }
            ],
          },
      '/client/v3/admin/whois/%40alice%3Aexample.com': (var req) => {
            'user_id': '@peter:rabbit.rocks',
            'devices': {
              'teapot': {
                'sessions': [
                  {
                    'connections': [
                      {
                        'ip': '127.0.0.1',
                        'last_seen': 1411996332123,
                        'user_agent': 'curl/7.31.0-DEV',
                      },
                      {
                        'ip': '10.0.0.2',
                        'last_seen': 1411996332123,
                        'user_agent':
                            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2062.120 Safari/537.36',
                      }
                    ],
                  }
                ],
              },
            },
          },
      '/client/v3/user/%40alice%3Aexample.com/account_data/test.account.data':
          (var req) => {'foo': 'bar'},
      '/client/v3/user/%40alice%3Aexample.com/rooms/1234/account_data/test.account.data':
          (var req) => {'foo': 'bar'},
      '/client/v3/directory/room/%23testalias%3Aexample.com': (var reqI) => {
            'room_id': '!abnjk1jdasj98:capuchins.com',
            'servers': ['capuchins.com', 'matrix.org', 'another.com'],
          },
      '/client/v3/account/3pid': (var req) => {
            'threepids': [
              {
                'medium': 'email',
                'address': 'monkey@banana.island',
                'validated_at': 1535176800000,
                'added_at': 1535336848756,
              }
            ],
          },
      '/client/v3/devices': (var req) => {
            'devices': [
              {
                'device_id': 'QBUAZIFURK',
                'display_name': 'android',
                'last_seen_ip': '1.2.3.4',
                'last_seen_ts': 1474491775024,
              }
            ],
          },
      '/client/v3/notifications?from=1234&limit=10&only=1234': (var req) => {
            'next_token': 'abcdef',
            'notifications': [
              {
                'actions': ['notify'],
                'profile_tag': 'hcbvkzxhcvb',
                'read': true,
                'room_id': '!abcdefg:example.com',
                'ts': 1475508881945,
                'event': {
                  'content': {
                    'body': 'This is an example text message',
                    'msgtype': 'm.text',
                    'format': 'org.matrix.custom.html',
                    'formatted_body': '<b>This is an example text message</b>',
                  },
                  'type': 'm.room.message',
                  'event_id': '\$143273582443PhrSn:example.org',
                  'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
                  'sender': '@example:example.org',
                  'origin_server_ts': 1432735824653,
                  'unsigned': {'age': 1234},
                },
              }
            ],
          },
      '/client/v3/devices/QBUAZIFURK': (var req) => {
            'device_id': 'QBUAZIFURK',
            'display_name': 'android',
            'last_seen_ip': '1.2.3.4',
            'last_seen_ts': 1474491775024,
          },
      '/client/v3/profile/%40test%3AfakeServer.notExisting': (var reqI) =>
          {'displayname': 'Some First Name Some Last Name'},
      '/client/v3/profile/%40alice%3Aexample.com/displayname': (var reqI) =>
          {'displayname': 'Alice M'},
      '/client/v3/profile/%40alice%3Aexample.com/avatar_url': (var reqI) =>
          {'avatar_url': 'mxc://test'},
      '/client/v3/profile/%40alice%3Aexample.com': (var reqI) => {
            'avatar_url': 'mxc://test',
            'displayname': 'Alice M',
          },
      '/client/v3/voip/turnServer': (var req) => {
            'username': '1443779631:@user:example.com',
            'password': 'JlKfBy1QwLrO20385QyAtEyIv0=',
            'uris': [
              'turn:turn.example.com:3478?transport=udp',
              'turn:10.20.30.40:3478?transport=tcp',
              'turns:10.20.30.40:443?transport=tcp',
            ],
            'ttl': 86400,
          },
      '/client/v3/presence/${Uri.encodeComponent('@alice:example.com')}/status':
          (var req) => {
                'presence': 'unavailable',
                'last_active_ago': 420845,
                'status_msg': 'test',
                'currently_active': false,
              },
      '/client/v3/keys/changes?from=1234&to=1234': (var req) => {
            'changed': ['@alice:example.com', '@bob:example.org'],
            'left': ['@clara:example.com', '@doug:example.org'],
          },
      '/client/v3/pushers': (var req) => {
            'pushers': [
              {
                'pushkey': 'Xp/MzCt8/9DcSNE9cuiaoT5Ac55job3TdLSSmtmYl4A=',
                'kind': 'http',
                'app_id': 'face.mcapp.appy.prod',
                'app_display_name': 'Appy McAppface',
                'device_display_name': 'Alices Phone',
                'profile_tag': 'xyz',
                'lang': 'en-US',
                'data': {
                  'url': 'https://example.com/_matrix/push/v1/notify',
                  'format': 'event_id_only',
                },
              }
            ],
          },
      '/client/v3/publicRooms?limit=10&since=1234&server=example.com':
          (var req) => {
                'chunk': [
                  {
                    'aliases': ['#murrays:cheese.bar'],
                    'canonical_alias': '#murrays:cheese.bar',
                    'avatar_url': 'mxc://bleeker.street/CHEDDARandBRIE',
                    'guest_can_join': false,
                    'name': 'CHEESE',
                    'num_joined_members': 37,
                    'room_id': '!ol19s:bleecker.street',
                    'topic': 'Tasty tasty cheese',
                    'world_readable': true,
                  }
                ],
                'next_batch': 'p190q',
                'prev_batch': 'p1902',
                'total_room_count_estimate': 115,
              },
      '/client/v3/room/!localpart%3Aexample.com/aliases': (var req) => {
            'aliases': [
              '#somewhere:example.com',
              '#another:example.com',
              '#hat_trick:example.com',
            ],
          },
      '/client/v3/joined_rooms': (var req) => {
            'joined_rooms': ['!foo:example.com'],
          },
      '/client/v3/directory/list/room/!localpart%3Aexample.com': (var req) =>
          {'visibility': 'public'},
      '/client/v3/rooms/1/state/m.room.member/@alice:example.com': (var req) =>
          {'displayname': 'Alice'},
      '/client/v3/profile/%40getmeprofile%3Aexample.com': (var req) => {
            'avatar_url': 'mxc://test',
            'displayname': 'You got me (profile)',
          },
      '/client/v3/profile/%40getme%3Aexample.com': (var req) => {
            'avatar_url': 'mxc://test',
            'displayname': 'You got me',
          },
      '/client/v3/rooms/!localpart%3Aserver.abc/state/m.room.member/%40getme%3Aexample.com':
          (var req) => {
                'avatar_url': 'mxc://test',
                'displayname': 'You got me',
                'membership': 'knock',
              },
      '/client/v3/rooms/!localpart%3Aserver.abc/state/m.room.member/%40getmeempty%3Aexample.com':
          (var req) => {
                'membership': 'leave',
              },
      '/client/v3/profile/%40getmeempty%3Aexample.com': (var req) => {
            'avatar_url': 'mxc://test',
            'displayname': 'You got me (empty)',
          },
      '/client/v3/rooms/!localpart%3Aserver.abc/state': (var req) => [
            {
              'content': {'join_rule': 'public'},
              'type': 'm.room.join_rules',
              'event_id': '\$143273582443PhrSn:example.org',
              'room_id': '!636q39766251:example.com',
              'sender': '@example:example.org',
              'origin_server_ts': 1432735824653,
              'unsigned': {'age': 1234},
              'state_key': '',
            },
            {
              'content': {
                'membership': 'join',
                'avatar_url': 'mxc://example.org/SEsfnsuifSDFSSEF',
                'displayname': 'Alice Margatroid',
              },
              'type': 'm.room.member',
              'event_id': '\$143273582443PhrSn:example.org',
              'room_id': '!636q39766251:example.com',
              'sender': '@example:example.org',
              'origin_server_ts': 1432735824653,
              'unsigned': {'age': 1234},
              'state_key': '@alice:example.org',
            },
            {
              'content': {
                'creator': '@example:example.org',
                'room_version': '1',
                'm.federate': true,
                'predecessor': {
                  'event_id': '\$something:example.org',
                  'room_id': '!oldroom:example.org',
                },
              },
              'type': 'm.room.create',
              'event_id': '\$143273582443PhrSn:example.org',
              'room_id': '!636q39766251:example.com',
              'sender': '@example:example.org',
              'origin_server_ts': 1432735824653,
              'unsigned': {'age': 1234},
              'state_key': '',
            },
            {
              'content': {
                'ban': 50,
                'events': {'m.room.name': 100, 'm.room.power_levels': 100},
                'events_default': 0,
                'invite': 50,
                'kick': 50,
                'redact': 50,
                'state_default': 50,
                'users': {'@example:localhost': 100},
                'users_default': 0,
                'notifications': {'room': 20},
              },
              'type': 'm.room.power_levels',
              'event_id': '\$143273582443PhrSn:example.org',
              'room_id': '!636q39766251:example.com',
              'sender': '@example:example.org',
              'origin_server_ts': 1432735824653,
              'unsigned': {'age': 1234},
              'state_key': '',
            }
          ],
      '/client/v3/rooms/!localpart:server.abc/event/1234': (var req) => {
            'content': {
              'body': 'This is an example text message',
              'msgtype': 'm.text',
              'format': 'org.matrix.custom.html',
              'formatted_body': '<b>This is an example text message</b>',
            },
            'type': 'm.room.message',
            'event_id': '143273582443PhrSn:example.org',
            'room_id': '!localpart:server.abc',
            'sender': '@example:example.org',
            'origin_server_ts': 1432735824653,
            'unsigned': {'age': 1234},
          },
      '/client/v3/rooms/!localpart%3Aserver.abc/event/1234': (var req) => {
            'content': {
              'body': 'This is an example text message',
              'msgtype': 'm.text',
              'format': 'org.matrix.custom.html',
              'formatted_body': '<b>This is an example text message</b>',
            },
            'type': 'm.room.message',
            'event_id': '143273582443PhrSn:example.org',
            'room_id': '!localpart:server.abc',
            'sender': '@example:example.org',
            'origin_server_ts': 1432735824653,
            'unsigned': {'age': 1234},
          },
      '/client/v3/rooms/!1234%3Aexample.com/event/not_found': (var req) => {
            'errcode': 'M_NOT_FOUND',
            'error': 'Event not found',
          },
      '/client/v3/rooms/!1234%3Aexample.com/event/unencrypted_event':
          (var req) => {
                'content': {
                  'body': 'This is an example text message',
                  'msgtype': 'm.text',
                  'format': 'org.matrix.custom.html',
                  'formatted_body': '<b>This is an example text message</b>',
                },
                'type': 'm.room.message',
                'event_id': '143273582443PhrSn:example.org',
                'room_id': '!localpart:server.abc',
                'sender': '@example:example.org',
                'origin_server_ts': 1432735824653,
                'unsigned': {'age': 1234},
              },
      '/client/v3/rooms/!1234%3Aexample.com/event/encrypted_event': (var req) =>
          {
            'content': {
              'algorithm': 'm.megolm.v1.aes-sha2',
              'ciphertext': 'invalid',
              'device_id': 'SOME_DEVICE',
              'sender_key': 'invalid',
              'session_id': 'not_found',
            },
            'type': 'm.room.encrypted',
            'event_id': '143273582443PhrSn:example.org',
            'room_id': '!localpart:server.abc',
            'sender': '@example:example.org',
            'origin_server_ts': 1432735824653,
            'unsigned': {'age': 1234},
          },
      '/client/v3/rooms/!localpart%3Aserver.abc/messages?from=1234&dir=b&to=1234&limit=10&filter=%7B%22lazy_load_members%22%3Atrue%7D':
          (var req) => messagesResponsePast,
      '/client/v3/rooms/!localpart%3Aserver.abc/messages?from=&dir=b&limit=10&filter=%7B%22lazy_load_members%22%3Atrue%7D':
          (var req) => messagesResponsePast,
      '/client/v3/rooms/!1234%3Aexample.com/messages?from=1234&dir=b&limit=30&filter=%7B%22lazy_load_members%22%3Atrue%7D':
          (var req) => messagesResponsePast,
      '/client/v3/rooms/!localpart%3Aserver.abc/messages?from=t456&dir=f&to=1234&limit=10&filter=%7B%22lazy_load_members%22%3Atrue%7D':
          (var req) => messagesResponseFuture,
      '/client/v3/rooms/!1234%3Aexample.com/messages?from=t456&dir=f&limit=30&filter=%7B%22lazy_load_members%22%3Atrue%7D':
          (var req) => messagesResponseFuture,
      '/client/v3/rooms/!localpart%3Aserver.abc/messages?from=t789&dir=f&to=1234&limit=10&filter=%7B%22lazy_load_members%22%3Atrue%7D':
          (var req) => messagesResponseFutureEnd,
      '/client/v3/rooms/!1234%3Aexample.com/messages?from=t789&dir=f&limit=30&filter=%7B%22lazy_load_members%22%3Atrue%7D':
          (var req) => messagesResponseFutureEnd,
      '/client/v3/rooms/!5345234234%3Aexample.com/messages?from=t_1234a&dir=b&limit=30&filter=%7B%22lazy_load_members%22%3Atrue%7D':
          (var req) => archivesMessageResponse,
      '/client/versions': (var req) => {
            'versions': ['v1.1', 'v1.2', 'v1.11'],
            'unstable_features': {'m.lazy_load_members': true},
          },
      '/client/v3/login': (var req) => {
            'flows': [
              {'type': 'm.login.password'},
            ],
          },
      '/client/v3/rooms/!localpart%3Aserver.abc/joined_members': (var req) => {
            'joined': {
              '@bar:example.com': {
                'display_name': 'Bar',
                'avatar_url': 'mxc://riot.ovh/printErCATzZijQsSDWorRaK',
              },
            },
          },
      '/client/v3/rooms/!localpart%3Aserver.abc/members?at=1234&membership=join&not_membership=leave':
          (var req) => {
                'chunk': [
                  {
                    'content': {
                      'membership': 'join',
                      'avatar_url': 'mxc://example.org/SEsfnsuifSDFSSEF',
                      'displayname': 'Alice Margatroid',
                    },
                    'type': 'm.room.member',
                    'event_id': '§143273582443PhrSn:example.org',
                    'room_id': '!636q39766251:example.com',
                    'sender': '@alice:example.com',
                    'origin_server_ts': 1432735824653,
                    'unsigned': {'age': 1234},
                    'state_key': '@alice:example.com',
                  }
                ],
              },
      '/client/v3/rooms/!696r7674:example.com/members': (var req) => {
            'chunk': [
              {
                'content': {
                  'membership': 'join',
                  'avatar_url': 'mxc://example.org/SEsfnsuifSDFSSEF',
                  'displayname': 'Alice Margatroid',
                },
                'type': 'm.room.member',
                'event_id': '§143273582443PhrSn:example.org',
                'room_id': '!636q39766251:example.com',
                'sender': '@alice:example.com',
                'origin_server_ts': 1432735824653,
                'unsigned': {'age': 1234},
                'state_key': '@alice:example.com',
              }
            ],
          },
      '/client/v3/rooms/!726s6s6q%3Aexample.com/members': (var req) => {
            'chunk': [
              {
                'content': {
                  'membership': 'join',
                  'avatar_url': 'mxc://example.org/SEsfnsuifSDFSSEF',
                  'displayname': 'Alice Margatroid',
                },
                'type': 'm.room.member',
                'event_id': '§143273582443PhrSn:example.org',
                'room_id': '!636q39766251:example.com',
                'sender': '@alice:example.com',
                'origin_server_ts': 1432735824653,
                'unsigned': {'age': 1234},
                'state_key': '@alice:example.com',
              }
            ],
          },
      '/client/v3/rooms/!localpart%3Aserver.abc/members': (var req) => {
            'chunk': [
              {
                'type': 'm.room.member',
                'content': {'membership': 'join', 'displayname': 'YOU'},
                'sender': '@test:fakeServer.notExisting',
                'state_key': '@test:fakeServer.notExisting',
                'room_id': '!localpart%3Aserver.abc',
                'event_id': '§143273582443PhrSn2:example.org',
                'origin_server_ts': 1432735824653,
                'unsigned': {'age': 1234},
              },
              {
                'type': 'm.room.member',
                'content': {
                  'membership': 'join',
                  'displayname': 'Alice Margatroid',
                },
                'sender': '@alice:matrix.org',
                'state_key': '@alice:matrix.org',
                'room_id': '!localpart%3Aserver.abc',
                'event_id': '§143273582443PhrSn3:example.org',
                'origin_server_ts': 1432735824653,
                'unsigned': {'age': 1234},
              },
              {
                'type': 'm.room.member',
                'content': {'membership': 'invite', 'displayname': 'Bob'},
                'sender': '@bob:example.com',
                'state_key': '@bob:example.com',
                'room_id': '!localpart%3Aserver.abc',
                'event_id': '§143273582443PhrSn4:example.org',
                'origin_server_ts': 1432735824653,
                'unsigned': {'age': 1234},
              },
              {
                'type': 'm.room.member',
                'content': {'membership': 'invite', 'displayname': 'Charley'},
                'sender': '@charley:example.org',
                'state_key': '@charley:example.org',
                'room_id': '!localpart%3Aserver.abc',
                'event_id': '§143273582443PhrSn5:example.org',
                'origin_server_ts': 1432735824653,
                'unsigned': {'age': 1234},
              },
              {
                'type': 'm.room.member',
                'content': {
                  'membership': 'join',
                  'avatar_url': 'mxc://example.org/SEsfnsuifSDFSSEF',
                  'displayname': 'Alice Margatroid',
                },
                'sender': '@example:example.org',
                'state_key': '@alice:example.org',
                'room_id': '!localpart%3Aserver.abc',
                'event_id': '§143273582443PhrSn6:example.org',
                'origin_server_ts': 1432735824653,
                'unsigned': {'age': 1234},
              },
            ],
          },
      '/client/v3/pushrules/global/content/nocake': (var req) => {
            'actions': ['dont_notify'],
            'pattern': 'cake*lie',
            'rule_id': 'nocake',
            'enabled': true,
            'default': false,
          },
      '/client/v3/pushrules/global/content/nocake/enabled': (var req) => {
            'enabled': true,
          },
      '/client/v3/pushrules/global/content/nocake/actions': (var req) => {
            'actions': ['notify'],
          },
      '/client/v3/pushrules': (var req) => {
            'global': {
              'content': [
                {
                  'actions': [
                    'notify',
                    {'set_tweak': 'sound', 'value': 'default'},
                    {'set_tweak': 'highlight'},
                  ],
                  'default': true,
                  'enabled': true,
                  'pattern': 'alice',
                  'rule_id': '.m.rule.contains_user_name',
                }
              ],
              'override': [
                {
                  'actions': ['dont_notify'],
                  'conditions': [],
                  'default': true,
                  'enabled': false,
                  'rule_id': '.m.rule.master',
                },
                {
                  'actions': ['dont_notify'],
                  'conditions': [
                    {
                      'key': 'content.msgtype',
                      'kind': 'event_match',
                      'pattern': 'm.notice',
                    }
                  ],
                  'default': true,
                  'enabled': true,
                  'rule_id': '.m.rule.suppress_notices',
                }
              ],
              'room': [],
              'sender': [],
              'underride': [
                {
                  'actions': [
                    'notify',
                    {'set_tweak': 'sound', 'value': 'ring'},
                    {'set_tweak': 'highlight', 'value': false},
                  ],
                  'conditions': [
                    {
                      'key': 'type',
                      'kind': 'event_match',
                      'pattern': 'm.call.invite',
                    }
                  ],
                  'default': true,
                  'enabled': true,
                  'rule_id': '.m.rule.call',
                },
                {
                  'actions': [
                    'notify',
                    {'set_tweak': 'sound', 'value': 'default'},
                    {'set_tweak': 'highlight'},
                  ],
                  'conditions': [
                    {'kind': 'contains_display_name'},
                  ],
                  'default': true,
                  'enabled': true,
                  'rule_id': '.m.rule.contains_display_name',
                },
                {
                  'actions': [
                    'notify',
                    {'set_tweak': 'sound', 'value': 'default'},
                    {'set_tweak': 'highlight', 'value': false},
                  ],
                  'conditions': [
                    {'is': '2', 'kind': 'room_member_count'},
                  ],
                  'default': true,
                  'enabled': true,
                  'rule_id': '.m.rule.room_one_to_one',
                },
                {
                  'actions': [
                    'notify',
                    {'set_tweak': 'sound', 'value': 'default'},
                    {'set_tweak': 'highlight', 'value': false},
                  ],
                  'conditions': [
                    {
                      'key': 'type',
                      'kind': 'event_match',
                      'pattern': 'm.room.member',
                    },
                    {
                      'key': 'content.membership',
                      'kind': 'event_match',
                      'pattern': 'invite',
                    },
                    {
                      'key': 'state_key',
                      'kind': 'event_match',
                      'pattern': '@alice:example.com',
                    }
                  ],
                  'default': true,
                  'enabled': true,
                  'rule_id': '.m.rule.invite_for_me',
                },
                {
                  'actions': [
                    'notify',
                    {'set_tweak': 'highlight', 'value': false},
                  ],
                  'conditions': [
                    {
                      'key': 'type',
                      'kind': 'event_match',
                      'pattern': 'm.room.member',
                    }
                  ],
                  'default': true,
                  'enabled': true,
                  'rule_id': '.m.rule.member_event',
                },
                {
                  'actions': [
                    'notify',
                    {'set_tweak': 'highlight', 'value': false},
                  ],
                  'conditions': [
                    {
                      'key': 'type',
                      'kind': 'event_match',
                      'pattern': 'm.room.message',
                    }
                  ],
                  'default': true,
                  'enabled': true,
                  'rule_id': '.m.rule.message',
                }
              ],
            },
          },
      '/client/v3/sync?filter=%7B%22room%22%3A%7B%22include_leave%22%3Atrue%2C%22state%22%3A%7B%22lazy_load_members%22%3Atrue%7D%2C%22timeline%22%3A%7B%22limit%22%3A10%7D%7D%7D&timeout=0':
          (var req) => archiveSyncResponse,
      '/client/v3/sync?filter=1234&timeout=0': (var req) => syncResponse,
      '/client/v3/sync?filter=1234&since=1234&full_state=false&set_presence=unavailable&timeout=15':
          (var req) => syncResponse,
      '/client/v3/register/available?username=testuser': (var req) =>
          {'available': true},
      '/client/v3/user/${Uri.encodeComponent('@test:fakeServer.notExisting')}/filter/1234':
          (var req) => {
                'room': {
                  'state': {
                    'types': ['m.room.*'],
                    'not_rooms': ['!726s6s6q:example.com'],
                  },
                  'timeline': {
                    'limit': 10,
                    'types': ['m.room.message'],
                    'not_rooms': ['!726s6s6q:example.com'],
                    'not_senders': ['@spam:example.com'],
                  },
                  'ephemeral': {
                    'types': ['m.receipt', 'm.typing'],
                    'not_rooms': ['!726s6s6q:example.com'],
                    'not_senders': ['@spam:example.com'],
                  },
                  'account_data': {
                    'types': ['m.receipt', 'm.typing'],
                    'not_rooms': ['!726s6s6q:example.com'],
                    'not_senders': ['@spam:example.com'],
                  },
                },
                'presence': {
                  'types': ['m.presence'],
                  'not_senders': ['@alice:example.com'],
                },
                'event_format': 'client',
                'event_fields': ['type', 'content', 'sender'],
              },
      '/client/v3/room_keys/version': (var req) => {
            'algorithm': AlgorithmTypes.megolmBackupV1Curve25519AesSha2,
            'auth_data': {
              'public_key': 'GXYaxqhNhUK28zUdxOmEsFRguz+PzBsDlTLlF0O0RkM',
              'signatures': {},
            },
            'count': 0,
            'etag': '0',
            'version': '5',
          },
      '/client/v3/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}/${Uri.encodeComponent('ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU')}?version=5':
          (var req) => {
                'first_message_index': 0,
                'forwarded_count': 0,
                'is_verified': true,
                'session_data': {
                  'ephemeral': 'fwRxYh+seqLykz5mQCLypJ4/59URdcFJ2s69OU1dGRc',
                  'ciphertext':
                      '19jkQYlbgdP+VL9DH3qY/Dvpk6onJZgf+6frZFl1TinPCm9OMK9AZZLuM1haS9XLAUK1YsREgjBqfl6T+Tq8JlJ5ONZGg2Wttt24sGYc0iTMZJ8rXcNDeKMZhM96ETyjufJSeYoXLqifiVLDw9rrVBmNStF7PskYp040em+0OZ4pF85Cwsdf7l9V7MMynzh9BoXqVUCBiwT03PNYH9AEmNUxXX+6ZwCpe/saONv8MgGt5uGXMZIK29phA3D8jD6uV/WOHsB8NjHNq9FrfSEAsl+dAcS4uiYie4BKSSeQN+zGAQqu1MMW4OAdxGOuf8WpIINx7n+7cKQfxlmc/Cgg5+MmIm2H0oDwQ+Xu7aSxp1OCUzbxQRdjz6+tnbYmZBuH0Ov2RbEvC5tDb261LRqKXpub0llg5fqKHl01D0ahv4OAQgRs5oU+4mq+H2QGTwIFGFqP9tCRo0I+aICawpxYOfoLJpFW6KvEPnM2Lr3sl6Nq2fmkz6RL5F7nUtzxN8OKazLQpv8DOYzXbi7+ayEsqS0/EINetq7RfCqgjrEUgfNWYuFXWqvUT8lnxLdNu+8cyrJqh1UquFjXWTw1kWcJ0pkokVeBtK9YysCnF1UYh/Iv3rl2ZoYSSLNtuvMSYlYHggZ8xV8bz9S3X2/NwBycBiWIy5Ou/OuSX7trIKgkkmda0xjBWEM1a2acVuqu2OFbMn2zFxm2a3YwKP//OlIgMg',
                  'mac': 'QzKV/fgAs4U',
                },
              },
      '/client/v3/room_keys/keys/${Uri.encodeComponent('!getroomkeys726s6s6q:example.com')}?version=5':
          (var req) => {
                'sessions': {
                  'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU': {
                    'first_message_index': 0,
                    'forwarded_count': 0,
                    'is_verified': true,
                    'session_data': {
                      'ephemeral':
                          'fwRxYh+seqLykz5mQCLypJ4/59URdcFJ2s69OU1dGRc',
                      'ciphertext':
                          '19jkQYlbgdP+VL9DH3qY/Dvpk6onJZgf+6frZFl1TinPCm9OMK9AZZLuM1haS9XLAUK1YsREgjBqfl6T+Tq8JlJ5ONZGg2Wttt24sGYc0iTMZJ8rXcNDeKMZhM96ETyjufJSeYoXLqifiVLDw9rrVBmNStF7PskYp040em+0OZ4pF85Cwsdf7l9V7MMynzh9BoXqVUCBiwT03PNYH9AEmNUxXX+6ZwCpe/saONv8MgGt5uGXMZIK29phA3D8jD6uV/WOHsB8NjHNq9FrfSEAsl+dAcS4uiYie4BKSSeQN+zGAQqu1MMW4OAdxGOuf8WpIINx7n+7cKQfxlmc/Cgg5+MmIm2H0oDwQ+Xu7aSxp1OCUzbxQRdjz6+tnbYmZBuH0Ov2RbEvC5tDb261LRqKXpub0llg5fqKHl01D0ahv4OAQgRs5oU+4mq+H2QGTwIFGFqP9tCRo0I+aICawpxYOfoLJpFW6KvEPnM2Lr3sl6Nq2fmkz6RL5F7nUtzxN8OKazLQpv8DOYzXbi7+ayEsqS0/EINetq7RfCqgjrEUgfNWYuFXWqvUT8lnxLdNu+8cyrJqh1UquFjXWTw1kWcJ0pkokVeBtK9YysCnF1UYh/Iv3rl2ZoYSSLNtuvMSYlYHggZ8xV8bz9S3X2/NwBycBiWIy5Ou/OuSX7trIKgkkmda0xjBWEM1a2acVuqu2OFbMn2zFxm2a3YwKP//OlIgMg',
                      'mac': 'QzKV/fgAs4U',
                    },
                  },
                },
              },
      '/client/v3/room_keys/keys?version=5': (var req) => {
            'rooms': {
              '!getallkeys726s6s6q:example.com': {
                'sessions': {
                  'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU': {
                    'first_message_index': 0,
                    'forwarded_count': 0,
                    'is_verified': true,
                    'session_data': {
                      'ephemeral':
                          'fwRxYh+seqLykz5mQCLypJ4/59URdcFJ2s69OU1dGRc',
                      'ciphertext':
                          '19jkQYlbgdP+VL9DH3qY/Dvpk6onJZgf+6frZFl1TinPCm9OMK9AZZLuM1haS9XLAUK1YsREgjBqfl6T+Tq8JlJ5ONZGg2Wttt24sGYc0iTMZJ8rXcNDeKMZhM96ETyjufJSeYoXLqifiVLDw9rrVBmNStF7PskYp040em+0OZ4pF85Cwsdf7l9V7MMynzh9BoXqVUCBiwT03PNYH9AEmNUxXX+6ZwCpe/saONv8MgGt5uGXMZIK29phA3D8jD6uV/WOHsB8NjHNq9FrfSEAsl+dAcS4uiYie4BKSSeQN+zGAQqu1MMW4OAdxGOuf8WpIINx7n+7cKQfxlmc/Cgg5+MmIm2H0oDwQ+Xu7aSxp1OCUzbxQRdjz6+tnbYmZBuH0Ov2RbEvC5tDb261LRqKXpub0llg5fqKHl01D0ahv4OAQgRs5oU+4mq+H2QGTwIFGFqP9tCRo0I+aICawpxYOfoLJpFW6KvEPnM2Lr3sl6Nq2fmkz6RL5F7nUtzxN8OKazLQpv8DOYzXbi7+ayEsqS0/EINetq7RfCqgjrEUgfNWYuFXWqvUT8lnxLdNu+8cyrJqh1UquFjXWTw1kWcJ0pkokVeBtK9YysCnF1UYh/Iv3rl2ZoYSSLNtuvMSYlYHggZ8xV8bz9S3X2/NwBycBiWIy5Ou/OuSX7trIKgkkmda0xjBWEM1a2acVuqu2OFbMn2zFxm2a3YwKP//OlIgMg',
                      'mac': 'QzKV/fgAs4U',
                    },
                  },
                },
              },
            },
          },
      '/client/unstable/org.matrix.msc3814.v1/dehydrated_device': (var _) => {
            'device_id': 'DEHYDDEV',
            'device_data': {'algorithm': 'some.famedly.proprietary.algorithm'},
          },
    },
    'POST': {
      '/client/v3/refresh': (var req) => {
            'access_token': 'a_new_token',
            'expires_in_ms': 1000 * 60 * 5,
            'refresh_token': 'another_new_token',
          },
      '/client/v3/delete_devices': (var req) => {},
      '/client/v3/account/3pid/add': (var req) => {},
      '/client/v3/account/3pid/bind': (var req) => {},
      '/client/v3/account/3pid/delete': (var req) =>
          {'id_server_unbind_result': 'success'},
      '/client/v3/account/3pid/unbind': (var req) =>
          {'id_server_unbind_result': 'success'},
      '/client/v3/account/password': (var req) => {},
      '/client/v3/rooms/1234/report/1234': (var req) => {},
      '/client/v3/search': (var req) => {
            'search_categories': {
              'room_events': {
                'groups': {
                  'room_id': {
                    '!qPewotXpIctQySfjSy:localhost': {
                      'order': 1,
                      'next_batch': 'BdgFsdfHSf-dsFD',
                      'results': ['\$144429830826TWwbB:localhost'],
                    },
                  },
                },
                'highlights': ['martians', 'men'],
                'next_batch': '5FdgFsd234dfgsdfFD',
                'count': 1224,
                'results': [
                  {
                    'rank': 0.00424866,
                    'result': {
                      'content': {
                        'body': 'This is an example text message',
                        'msgtype': 'm.text',
                        'format': 'org.matrix.custom.html',
                        'formatted_body':
                            '<b>This is an example text message</b>',
                      },
                      'type': 'm.room.message',
                      'event_id': '\$144429830826TWwbB:localhost',
                      'room_id': '!qPewotXpIctQySfjSy:localhost',
                      'sender': '@example:example.org',
                      'origin_server_ts': 1432735824653,
                      'unsigned': {'age': 1234},
                    },
                  }
                ],
              },
            },
          },
      '/client/v3/account/deactivate': (var req) =>
          {'id_server_unbind_result': 'success'},
      '/client/v3/user_directory/search': (var req) => {
            'results': [
              {
                'user_id': '@foo:bar.com',
                'display_name': 'Foo',
                'avatar_url': 'mxc://bar.com/foo',
              }
            ],
            'limited': false,
          },
      '/client/v3/register/email/requestToken': (var req) => {
            'sid': '123abc',
            'submit_url': 'https://example.org/path/to/submitToken',
          },
      '/client/v3/register/msisdn/requestToken': (var req) => {
            'sid': '123abc',
            'submit_url': 'https://example.org/path/to/submitToken',
          },
      '/client/v3/account/password/email/requestToken': (var req) => {
            'sid': '123abc',
            'submit_url': 'https://example.org/path/to/submitToken',
          },
      '/client/v3/account/password/msisdn/requestToken': (var req) => {
            'sid': '123abc',
            'submit_url': 'https://example.org/path/to/submitToken',
          },
      '/client/v3/account/3pid/email/requestToken': (var req) => {
            'sid': '123abc',
            'submit_url': 'https://example.org/path/to/submitToken',
          },
      '/client/v3/account/3pid/msisdn/requestToken': (var req) => {
            'sid': '123abc',
            'submit_url': 'https://example.org/path/to/submitToken',
          },
      '/client/v3/rooms/!localpart%3Aexample.com/receipt/m.read/%241234%3Aexample.com':
          (var req) => {},
      '/client/v3/rooms/!localpart%3Aexample.com/read_markers': (var req) => {},
      '/client/v3/rooms/!1234%3Aexample.com/read_markers': (var req) => {},
      '/client/v3/user/${Uri.encodeComponent('@othertest:fakeServer.notExisting')}/filter':
          (var req) => {'filter_id': '1234'},
      '/client/v3/user/${Uri.encodeComponent('@test:fakeServer.notExisting')}/filter':
          (var req) => {'filter_id': '1234'},
      '/client/v3/publicRooms?server=example.com': (var req) => {
            'chunk': [
              {
                'aliases': ['#murrays:cheese.bar'],
                'canonical_alias': '#murrays:cheese.bar',
                'avatar_url': 'mxc://bleeker.street/CHEDDARandBRIE',
                'guest_can_join': false,
                'name': 'CHEESE',
                'num_joined_members': 37,
                'room_id': '!ol19s:bleecker.street',
                'topic': 'Tasty tasty cheese',
                'world_readable': true,
              }
            ],
            'next_batch': 'p190q',
            'prev_batch': 'p1902',
            'total_room_count_estimate': 115,
          },
      '/client/v3/keys/claim': (var req) => {
            'failures': {},
            'one_time_keys': {
              if (decodeJson(req)['one_time_keys']['@alice:example.com'] !=
                  null)
                '@alice:example.com': {
                  'JLAFKJWSCS': {
                    'signed_curve25519:AAAAAQ': {
                      'key': 'ikMXajRlkS7Xi9CROrAh3jXnbygk8mLBdSaY9/al0X0',
                      'signatures': {
                        '@alice:example.com': {
                          'ed25519:JLAFKJWSCS':
                              'XdboCa0Ljoh0Y0i/IVnmMqy/+T1hJyu8BA/nRYniJMQ7QWh/pGS5AsWswdARD+MAX+r4u98Qzk0y27HUddZXDA',
                        },
                      },
                    },
                  },
                },
              if (decodeJson(req)['one_time_keys']
                      ['@test:fakeServer.notExisting'] !=
                  null)
                '@test:fakeServer.notExisting': {
                  'GHTYAJCE': {
                    'signed_curve25519:AAAAAQ': {
                      'key': 'qc72ve94cA28iuE0fXa98QO3uls39DHWdQlYyvvhGh0',
                      'signatures': {
                        '@test:fakeServer.notExisting': {
                          'ed25519:GHTYAJCE':
                              'dFwffr5kTKefO7sjnWLMhTzw7oV31nkPIDRxFy5OQT2OP5++Ao0KRbaBZ6qfuT7lW1owKK0Xk3s7QTBvc/eNDA',
                        },
                      },
                    },
                  },
                },
            },
          },
      '/client/v3/rooms/!localpart%3Aexample.com/invite': (var req) => {},
      '/client/v3/rooms/!1234%3AfakeServer.notExisting/invite': (var req) => {},
      '/client/v3/rooms/!localpart%3Aexample.com/leave': (var req) => {},
      '/client/v3/rooms/!1234%3AfakeServer.notExisting/leave': (var req) => {},
      '/client/v3/rooms/!localpart%3Aexample.com/forget': (var req) => {},
      '/client/v3/rooms/!localpart%3Aserver.abc/kick': (var req) => {},
      '/client/v3/rooms/!1234%3AfakeServer.notExisting/kick': (var req) => {},
      '/client/v3/rooms/!localpart%3Aexample.com/kick': (var req) => {},
      '/client/v3/rooms/!localpart%3Aexample.com/ban': (var req) => {},
      '/client/v3/rooms/!1234%3AfakeServer.notExisting/ban': (var req) => {},
      '/client/v3/rooms/!localpart%3Aexample.com/unban': (var req) => {},
      '/client/v3/rooms/!1234%3AfakeServer.notExisting/unban': (var req) => {},
      '/client/v3/rooms/!localpart%3Aexample.com/join': (var req) =>
          {'room_id': '!localpart:example.com'},
      '/client/v3/join/!localpart%3Aexample.com?server_name=example.com&server_name=example.abc':
          (var req) => {'room_id': '!localpart:example.com'},
      '/client/v3/join/!newroom%3Aexample.com': (var req) =>
          {'room_id': '!newroom%3A:example.com'},
      '/client/v3/keys/upload': (var req) => {
            'one_time_key_counts': {
              'curve25519': 10,
              'signed_curve25519':
                  tryCast<Map<String, Object?>>(decodeJson(req))
                          ?.tryGetMap<String, Object?>('one_time_keys')
                          ?.keys
                          .length ??
                      0,
            },
          },
      '/client/v3/keys/query': (var req) => {
            'failures': {},
            'device_keys': {
              '@alice:example.com': {
                'JLAFKJWSCS': {
                  'user_id': '@alice:example.com',
                  'device_id': 'JLAFKJWSCS',
                  'algorithms': [
                    AlgorithmTypes.olmV1Curve25519AesSha2,
                    AlgorithmTypes.megolmV1AesSha2,
                  ],
                  'keys': {
                    'curve25519:JLAFKJWSCS':
                        'L+4+JCl8MD63dgo8z5Ta+9QAHXiANyOVSfgbHA5d3H8',
                    'ed25519:JLAFKJWSCS':
                        'rUFJftIWpFF/jqqz3bexGGYiG8UobKhzkeabqw1v0zM',
                  },
                  'signatures': {
                    '@alice:example.com': {
                      'ed25519:JLAFKJWSCS':
                          'go3mi5o3Ile+Ik+lCEpHmBmyJmKWfnRDCBBvfaVlKsMyha5IORuYcxwEUrAeLyAeeeHvkWDFX+No5eY1jYeKBw',
                    },
                  },
                  'unsigned': {'device_display_name': 'Alices mobile phone'},
                },
                'OTHERDEVICE': {
                  'user_id': '@alice:example.com',
                  'device_id': 'OTHERDEVICE',
                  'algorithms': [
                    AlgorithmTypes.olmV1Curve25519AesSha2,
                    AlgorithmTypes.megolmV1AesSha2,
                  ],
                  'keys': {
                    'curve25519:OTHERDEVICE':
                        'wMIDhiQl5jEXQrTB03ePOSQfR8sA/KMrW0CIfFfXKEE',
                    'ed25519:OTHERDEVICE':
                        '2Lyaj5NB7HPqKZMjZpA/pECXuQ+9wi8AGFdw33y3DuQ',
                  },
                  'signatures': {
                    '@alice:example.com': {
                      'ed25519:OTHERDEVICE':
                          'bwHd6ylISP13AICdDPd0HQd4V6dvvd4vno8/OwUNdm9UAprr3YjkDqVw425I74u2UQAarq9bytBqVqFyD6trAw',
                    },
                  },
                },
              },
              '@test:fakeServer.notExisting': {
                'GHTYAJCE': {
                  'user_id': '@test:fakeServer.notExisting',
                  'device_id': 'GHTYAJCE',
                  'algorithms': [
                    AlgorithmTypes.olmV1Curve25519AesSha2,
                    AlgorithmTypes.megolmV1AesSha2,
                  ],
                  'keys': {
                    'curve25519:GHTYAJCE':
                        '7rvl3jORJkBiK4XX1e5TnGnqz068XfYJ0W++Ml63rgk',
                    'ed25519:GHTYAJCE':
                        'gjL//fyaFHADt9KBADGag8g7F8Up78B/K1zXeiEPLJo',
                  },
                  'signatures': {
                    '@test:fakeServer.notExisting': {
                      'ed25519:GHTYAJCE':
                          'NEQeTgv7ew1IZSLQphWd0y60EdHdcNfHgvoaMQco5XKeIYyiUZIWd7F4x/mkPDjUizv6yWMbTDCWdSg5XcgNBA',
                      'ed25519:F9ypFzgbISXCzxQhhSnXMkc1vq12Luna3Nw5rqViOJY':
                          'Q4/55vZjEJD7M2EC40bgZqd9Zuy/4C75UPVopJdXeioQVaKtFf6EF0nUUuql0yD+r3hinsZcock0wO6Q2xcoAQ',
                    },
                  },
                },
                'OTHERDEVICE': {
                  'user_id': '@test:fakeServer.notExisting',
                  'device_id': 'OTHERDEVICE',
                  'algorithms': [
                    AlgorithmTypes.olmV1Curve25519AesSha2,
                    AlgorithmTypes.megolmV1AesSha2,
                  ],
                  'keys': {
                    'curve25519:OTHERDEVICE':
                        'R96BA0qE1+QAWLp7E1jyWSTJ1VXMLpEdiM2SZHlKMXM',
                    'ed25519:OTHERDEVICE':
                        'EQo9eYbSygIbOR+tVJziqAY1NI6Gga+JQOVIqJe4mr4',
                  },
                  'signatures': {
                    '@test:fakeServer.notExisting': {
                      'ed25519:OTHERDEVICE':
                          '/rT6pVRypJWxGos1QcI7jHL9HwcA83nkHLHqMcRPeLSxXHh4oHWvC0/tl0Xg06ogyiGw4NuB7TpOISvJBdt7BA',
                      'ed25519:F9ypFzgbISXCzxQhhSnXMkc1vq12Luna3Nw5rqViOJY':
                          'qnjiLl36h/1jlLvcAgt46Igaod2T9lOSnoSVkV0KC+c7vYIjG4QBzXpH+hycfufOT/y+a/kl52dUTLQWctMKCA',
                    },
                  },
                },
              },
              '@othertest:fakeServer.notExisting': {
                'FOXDEVICE': {
                  'user_id': '@othertest:fakeServer.notExisting',
                  'device_id': 'FOXDEVICE',
                  'algorithms': [
                    AlgorithmTypes.olmV1Curve25519AesSha2,
                    AlgorithmTypes.megolmV1AesSha2,
                  ],
                  'keys': {
                    'curve25519:FOXDEVICE':
                        'JBG7ZaPn54OBC7TuIEiylW3BZ+7WcGQhFBPB9pogbAg',
                    'ed25519:FOXDEVICE':
                        'R5/p04tticvdlNIxiiBIP0j9OQWv8ep6eEU6/lWKDxw',
                  },
                  'signatures': {
                    '@othertest:fakeServer.notExisting': {
                      'ed25519:FOXDEVICE':
                          '2lJ3atmRIWgkyQNC9gvWEpxwuozsBQsg33M2IMDJqLhx/+g3Ds1vQ683dJsYIu04ORa4U0L9TqieHVpV/7qqDA',
                    },
                  },
                },
              },
            },
            'master_keys': {
              '@test:fakeServer.notExisting': {
                'user_id': '@test:fakeServer.notExisting',
                'usage': ['master'],
                'keys': {
                  'ed25519:82mAXjsmbTbrE6zyShpR869jnrANO75H8nYY0nDLoJ8':
                      '82mAXjsmbTbrE6zyShpR869jnrANO75H8nYY0nDLoJ8',
                },
                'signatures': {},
              },
              '@othertest:fakeServer.notExisting': {
                'user_id': '@othertest:fakeServer.notExisting',
                'usage': ['master'],
                'keys': {
                  'ed25519:92mAXjsmbTbrE6zyShpR869jnrANO75H8nYY0nDLoJ8':
                      '92mAXjsmbTbrE6zyShpR869jnrANO75H8nYY0nDLoJ8',
                },
                'signatures': {},
              },
            },
            'self_signing_keys': {
              '@test:fakeServer.notExisting': {
                'user_id': '@test:fakeServer.notExisting',
                'usage': ['self_signing'],
                'keys': {
                  'ed25519:F9ypFzgbISXCzxQhhSnXMkc1vq12Luna3Nw5rqViOJY':
                      'F9ypFzgbISXCzxQhhSnXMkc1vq12Luna3Nw5rqViOJY',
                },
                'signatures': {
                  '@test:fakeServer.notExisting': {
                    'ed25519:82mAXjsmbTbrE6zyShpR869jnrANO75H8nYY0nDLoJ8':
                        'afkrbGvPn5Zb5zc7Lk9cz2skI3QrzI/L0st1GS+/GATxNjMzc6vKmGu7r9cMb1GJxy4RdeUpfH3L7Fs/fNL1Dw',
                  },
                },
              },
              '@othertest:fakeServer.notExisting': {
                'user_id': '@othertest:fakeServer.notExisting',
                'usage': ['self_signing'],
                'keys': {
                  'ed25519:self_signing': 'self_signing',
                },
                'signatures': {},
              },
            },
            'user_signing_keys': {
              '@test:fakeServer.notExisting': {
                'user_id': '@test:fakeServer.notExisting',
                'usage': ['user_signing'],
                'keys': {
                  'ed25519:0PiwulzJ/RU86LlzSSZ8St80HUMN3dqjKa/orIJoA0g':
                      '0PiwulzJ/RU86LlzSSZ8St80HUMN3dqjKa/orIJoA0g',
                },
                'signatures': {
                  '@test:fakeServer.notExisting': {
                    'ed25519:82mAXjsmbTbrE6zyShpR869jnrANO75H8nYY0nDLoJ8':
                        'pvgbZxEbllaElhpiRnb7/uOIUhrglvHCFnpoxr3/5ZrWa0EK/uaefhex9eEV4uBLrHjHg2ymwdNaM7ap9+sBBg',
                  },
                },
              },
              '@othertest:fakeServer.notExisting': {
                'user_id': '@othertest:fakeServer.notExisting',
                'usage': ['user_signing'],
                'keys': {
                  'ed25519:user_signing': 'user_signing',
                },
                'signatures': {},
              },
            },
          },
      '/client/v3/register': (var req) => {
            'user_id': '@testuser:example.com',
            'access_token': '1234',
            'device_id': 'ABCD',
          },
      '/client/v3/register?kind=user': (var req) =>
          {'user_id': '@testuser:example.com'},
      '/client/v3/register?kind=guest': (var req) =>
          {'user_id': '@testuser:example.com'},
      '/client/v3/rooms/1234/upgrade': (var req) => {},
      '/client/v3/user/1234/openid/request_token': (var req) => {
            'access_token': 'SomeT0kenHere',
            'token_type': 'Bearer',
            'matrix_server_name': 'example.com',
            'expires_in': 3600.0,
          },
      '/client/v3/user/@test:fakeServer.notExisting/openid/request_token':
          (var req) => {
                'access_token': 'SomeT0kenHere',
                'token_type': 'Bearer',
                'matrix_server_name': 'example.com',
                'expires_in': 3600,
              },
      '/client/v3/login': (var req) => {
            'user_id': '@test:fakeServer.notExisting',
            'access_token': 'abc123',
            'refresh_token': 'refresh_abc123',
            'device_id': 'GHTYAJCE',
            'well_known': {
              'm.homeserver': {'base_url': 'https://example.org'},
              'm.identity_server': {'base_url': 'https://id.example.org'},
            },
          },
      '/media/v3/upload?filename=file.jpeg': (var req) =>
          {'content_uri': 'mxc://example.com/AQwafuaFswefuhsfAFAgsw'},
      '/client/v3/logout': (var reqI) => {},
      '/client/v3/pushers/set': (var reqI) => {},
      '/client/v3/join/1234': (var reqI) => {'room_id': '1234'},
      '/client/v3/logout/all': (var reqI) => {},
      '/client/v3/createRoom': (var reqI) => {
            'room_id': '!1234:fakeServer.notExisting',
          },
      '/client/v3/rooms/!localpart%3Aserver.abc/read_markers': (var reqI) => {},
      '/client/v3/rooms/!localpart:server.abc/kick': (var reqI) => {},
      '/client/v3/rooms/!localpart%3Aserver.abc/ban': (var reqI) => {},
      '/client/v3/rooms/!localpart%3Aserver.abc/unban': (var reqI) => {},
      '/client/v3/rooms/!localpart%3Aserver.abc/invite': (var reqI) => {},
      '/client/v3/keys/signatures/upload': (var reqI) => {'failures': {}},
      '/client/v3/room_keys/version': (var reqI) => {'version': '5'},
      '/client/unstable/org.matrix.msc3814.v1/dehydrated_device/DEHYDDEV/events?limit=100':
          (var _) => {
                'events': [
                  {
                    // this is the commented out m.room_key event - only encrypted
                    'sender': '@othertest:fakeServer.notExisting',
                    'content': {
                      'algorithm': AlgorithmTypes.olmV1Curve25519AesSha2,
                      'sender_key':
                          'JBG7ZaPn54OBC7TuIEiylW3BZ+7WcGQhFBPB9pogbAg',
                      'ciphertext': {
                        '7rvl3jORJkBiK4XX1e5TnGnqz068XfYJ0W++Ml63rgk': {
                          'type': 0,
                          'body':
                              'Awogyh7K4iLUQjcOxIfi7q7LhBBqv9w0mQ6JI9+U9tv7iF4SIHC6xb5YFWf9voRnmDBbd+0vxD/xDlVNRDlPIKliLGkYGiAkEbtlo+fng4ELtO4gSLKVbcFn7tZwZCEUE8H2miBsCCKABgMKIFrKDJwB7gM3lXPt9yVoh6gQksafKt7VFCNRN5KLKqsDEAAi0AX5EfTV7jJ1ZWAbxftjoSN6kCVIxzGclbyg1HjchmNCX7nxNCHWl+q5ZgqHYZVu2n2mCVmIaKD0kvoEZeY3tV1Itb6zf67BLaU0qgW/QzHCHg5a44tNLjucvL2mumHjIG8k0BY2uh+52HeiMCvSOvtDwHg7nzCASGdqPVCj9Kzw6z7F6nL4e3mYim8zvJd7f+mD9z3ARrypUOLGkTGYbB2PQOovf0Do8WzcaRzfaUCnuu/YVZWKK7DPgG8uhw/TjR6XtraAKZysF+4DJYMG9SQWx558r6s7Z5EUOF5CU2M35w1t1Xxllb3vrS83dtf9LPCrBhLsEBeYEUBE2+bTBfl0BDKqLiB0Cc0N0ixOcHIt6e40wAvW622/gMgHlpNSx8xG12u0s6h6EMWdCXXLWd9fy2q6glFUHvA67A35q7O+M8DVml7Y9xG55Y3DHkMDc9cwgwFkBDCAYQe6pQF1nlKytcVCGREpBs/gq69gHAStMQ8WEg38Lf8u8eBr2DFexrN4U+QAk+S//P3fJgf0bQx/Eosx4fvWSz9En41iC+ADCsWQpMbwHn4JWvtAbn3oW0XmL/OgThTkJMLiCymduYAa1Hnt7a3tP0KTL2/x11F02ggQHL28cCjq5W4zUGjWjl5wo2PsKB6t8aAvMg2ujGD2rCjb4yrv5VIzAKMOZLyj7K0vSK9gwDLQ/4vq+QnKUBG5zrcOze0hX+kz2909/tmAdeCH61Ypw7gbPUJAKnmKYUiB/UgwkJvzMJSsk/SEs5SXosHDI+HsJHJp4Mp4iKD0xRMst+8f9aTjaWwh8ZvELE1ZOhhCbF3RXhxi3x2Nu8ORIz+vhEQ1NOlMc7UIo98Fk/96T36vL/fviowT4C/0AlaapZDJBmKwhmwqisMjY2n1vY29oM2p5BzY1iwP7q9BYdRFst6xwo57TNSuRwQw7IhFsf0k+ABuPEZy5xB5nPHyIRTf/pr3Hw',
                        },
                      },
                    },
                    'type': 'm.room.encrypted',
                  },
                ],
                'next_batch': 'd1',
              },
    },
    'PUT': {
      '/client/v3/user/${Uri.encodeComponent('@alice:example.com')}/account_data/io.element.recent_emoji}':
          (var req) => {},
      '/client/v3/user/%40test%3AfakeServer.notExisting/account_data/io.element.recent_emoji':
          (var req) => {},
      '/client/v3/user/%40test%3AfakeServer.notExisting/account_data/m.ignored_user_list':
          (var req) => {},
      '/client/v3/presence/${Uri.encodeComponent('@alice:example.com')}/status':
          (var req) => {},
      '/client/v3/pushrules/global/content/nocake/enabled': (var req) => {},
      '/client/v3/pushrules/global/content/nocake/actions': (var req) => {},
      '/client/v3/rooms/!localpart%3Aserver.abc/state/m.room.history_visibility':
          (var req) => {'event_id': '1234'},
      '/client/v3/rooms/!localpart%3Aserver.abc/state/m.room.join_rules':
          (var req) => {'event_id': '1234'},
      '/client/v3/rooms/!localpart%3Aserver.abc/state/m.room.guest_access':
          (var req) => {'event_id': '1234'},
      '/client/v3/rooms/!calls%3Aexample.com/send/m.call.invite/1234':
          (var req) => {'event_id': '1234'},
      '/client/v3/rooms/!calls%3Aexample.com/send/m.call.answer/1234':
          (var req) => {'event_id': '1234'},
      '/client/v3/rooms/!calls%3Aexample.com/send/m.call.select_answer/1234':
          (var req) => {'event_id': '1234'},
      '/client/v3/rooms/!calls%3Aexample.com/send/m.call.reject/1234':
          (var req) => {'event_id': '1234'},
      '/client/v3/rooms/!calls%3Aexample.com/send/m.call.negotiate/1234':
          (var req) => {'event_id': '1234'},
      '/client/v3/rooms/!calls%3Aexample.com/send/m.call.candidates/1234':
          (var req) => {'event_id': '1234'},
      '/client/v3/rooms/!calls%3Aexample.com/send/m.call.hangup/1234':
          (var req) => {'event_id': '1234'},
      '/client/v3/rooms/!calls%3Aexample.com/send/m.call.replaces/1234':
          (var req) => {'event_id': '1234'},
      '/client/v3/rooms/!calls%3Aexample.com/send/m.call.asserted_identity/1234':
          (var req) => {'event_id': '1234'},
      '/client/v3/rooms/!calls%3Aexample.com/send/m.call.sdp_stream_metadata_changed/1234':
          (var req) => {'event_id': '1234'},
      '/client/v3/rooms/!calls%3Aexample.com/send/org.matrix.call.sdp_stream_metadata_changed/1234':
          (var req) => {'event_id': '1234'},
      '/client/v3/rooms/!calls%3Aexample.com/send/org.matrix.call.asserted_identity/1234':
          (var req) => {'event_id': '1234'},
      '/client/v3/rooms/!1234%3Aexample.com/redact/1143273582443PhrSn%3Aexample.org/1234':
          (var req) => {'event_id': '1234'},
      '/client/v3/rooms/!696r7674%3Aexample.com/send/org.matrix.msc3381.poll.start/1234':
          (var req) => {'event_id': '1234'},
      '/client/v3/rooms/!696r7674%3Aexample.com/send/org.matrix.msc3381.poll.response/1234':
          (var req) => {'event_id': '1234'},
      '/client/v3/pushrules/global/room/!localpart%3Aserver.abc': (var req) =>
          {},
      '/client/v3/pushrules/global/override/.m.rule.master/enabled':
          (var req) => {},
      '/client/v3/pushrules/global/content/nocake?before=1&after=2':
          (var req) => {},
      '/client/v3/devices/QBUAZIFURK': (var req) => {},
      '/client/v3/directory/room/%23testalias%3Aexample.com': (var reqI) => {},
      '/client/v3/rooms/!localpart%3Aserver.abc/send/m.room.message/testtxid':
          (var reqI) => {
                'event_id': '\$event${FakeMatrixApi.eventCounter++}',
              },
      '/client/v3/rooms/!localpart%3Aserver.abc/send/m.reaction/testtxid':
          (var reqI) => {
                'event_id': '\$event${FakeMatrixApi.eventCounter++}',
              },
      '/client/v3/rooms/!localpart%3Aexample.com/typing/%40alice%3Aexample.com':
          (var req) => {},
      '/client/v3/rooms/!1234%3Aexample.com/send/m.room.message/1234':
          (var reqI) => {
                'event_id': '\$event${FakeMatrixApi.eventCounter++}',
              },
      '/client/v3/rooms/!1234%3Aexample.com/send/m.room.message/newresend':
          (var reqI) => {
                'event_id': '\$event${FakeMatrixApi.eventCounter++}',
              },
      '/client/v3/user/%40test%3AfakeServer.notExisting/rooms/!localpart%3Aserver.abc/tags/m.favourite':
          (var req) => {},
      '/client/v3/user/%40alice%3Aexample.com/rooms/!localpart%3Aexample.com/tags/testtag':
          (var req) => {},
      '/client/v3/user/%40alice%3Aexample.com/account_data/test.account.data':
          (var req) => {},
      '/client/v3/user/%40test%3AfakeServer.notExisting/account_data/best%20animal':
          (var req) => {},
      '/client/v3/user/%40alice%3Aexample.com/rooms/1234/account_data/test.account.data':
          (var req) => {},
      '/client/v3/user/%40test%3AfakeServer.notExisting/rooms/!localpart%3Aserver.abc/account_data/m.marked_unread':
          (var req) => {},
      '/client/v3/user/%40test%3AfakeServer.notExisting/account_data/m.direct':
          (var req) => {},
      '/client/v3/user/%40othertest%3AfakeServer.notExisting/account_data/m.direct':
          (var req) => {},
      '/client/v3/profile/%40alice%3Aexample.com/displayname': (var reqI) => {},
      '/client/v3/profile/%40alice%3Aexample.com/avatar_url': (var reqI) => {},
      '/client/v3/profile/%40test%3AfakeServer.notExisting/avatar_url':
          (var reqI) => {},
      '/client/v3/rooms/!localpart%3Aserver.abc/state/m.room.encryption':
          (var reqI) => {'event_id': 'YUwRidLecu:example.com'},
      '/client/v3/rooms/!localpart%3Aserver.abc/state/m.room.avatar':
          (var reqI) => {'event_id': 'YUwRidLecu:example.com'},
      '/client/v3/rooms/!localpart%3Aserver.abc/send/m.room.message/1234':
          (var reqI) => {'event_id': 'YUwRidLecu:example.com'},
      '/client/v3/rooms/!localpart%3Aserver.abc/redact/1234/1234': (var reqI) =>
          {'event_id': 'YUwRidLecu:example.com'},
      '/client/v3/rooms/!localpart%3Aserver.abc/state/m.room.name':
          (var reqI) => {
                'event_id': '42',
              },
      '/client/v3/rooms/!localpart%3Aserver.abc/state/m.room.topic':
          (var reqI) => {
                'event_id': '42',
              },
      '/client/v3/rooms/!localpart%3Aserver.abc/state/m.room.pinned_events':
          (var reqI) => {
                'event_id': '42',
              },
      '/client/v3/rooms/!localpart%3Aserver.abc/state/m.room.power_levels':
          (var reqI) => {
                'event_id': '42',
              },
      '/client/v3/rooms/!calls%3Aexample.com/state/m.room.power_levels':
          (var reqI) => {
                'event_id': '42',
              },
      '/client/v3/directory/list/room/!localpart%3Aexample.com': (var req) =>
          {},
      '/client/v3/room_keys/version/5': (var req) => {},
      '/client/v3/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}/${Uri.encodeComponent('ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU')}?version=5':
          (var req) => {
                'etag': 'asdf',
                'count': 1,
              },
      '/client/v3/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}?version=5':
          (var req) => {
                'etag': 'asdf',
                'count': 1,
              },
      '/client/v3/room_keys/keys?version=5': (var req) => {
            'etag': 'asdf',
            'count': 1,
          },
      '/client/unstable/org.matrix.msc3814.v1/dehydrated_device': (var _) => {
            'device_id': 'DEHYDDEV',
          },
    },
    'DELETE': {
      '/unknown/token': (var req) => {'errcode': 'M_UNKNOWN_TOKEN'},
      '/client/v3/devices/QBUAZIFURK': (var req) => {},
      '/client/v3/directory/room/%23testalias%3Aexample.com': (var reqI) => {},
      '/client/v3/pushrules/global/content/nocake': (var req) => {},
      '/client/v3/pushrules/global/override/!localpart%3Aserver.abc':
          (var req) => {},
      '/client/v3/user/%40test%3AfakeServer.notExisting/rooms/!localpart%3Aserver.abc/tags/m.favourite':
          (var req) => {},
      '/client/v3/user/%40alice%3Aexample.com/rooms/!localpart%3Aexample.com/tags/testtag':
          (var req) => {},
      '/client/v3/room_keys/version/5': (var req) => {},
      '/client/v3/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}/${Uri.encodeComponent('ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU')}?version=5':
          (var req) => {
                'etag': 'asdf',
                'count': 1,
              },
      '/client/v3/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}?version=5':
          (var req) => {
                'etag': 'asdf',
                'count': 1,
              },
      '/client/v3/room_keys/keys?version=5': (var req) => {
            'etag': 'asdf',
            'count': 1,
          },
    },
  };
}
