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

import 'package:http/testing.dart';
import 'dart:convert';
import 'dart:core';
import 'dart:math';
import 'package:http/http.dart';

class FakeMatrixApi extends MockClient {
  FakeMatrixApi()
      : super((request) async {
          // Collect data from Request
          String action =
              request.url.path.split("/_matrix")[1] + "?" + request.url.query;
          if (action.endsWith("?")) action = action.replaceAll("?", "");
          final String method = request.method;
          final dynamic data =
              method == "GET" ? request.url.queryParameters : request.body;
          var res = {};

          //print("$method request to $action with Data: $data");

          // Sync requests with timeout
          if (data is Map<String, dynamic> && data["timeout"] is String) {
            await new Future.delayed(Duration(seconds: 5));
          }

          if (request.url.origin != "https://fakeserver.notexisting")
            return Response(
                "<html><head></head><body>Not found...</body></html>", 50);

          // Call API
          if (api.containsKey(method) && api[method].containsKey(action))
            res = api[method][action](data);
          else
            res = {
              "errcode": "M_UNRECOGNIZED",
              "error": "Unrecognized request"
            };

          return Response(json.encode(res), 100);
        });

  static Map<String, dynamic> syncResponse = {
    "next_batch": Random().nextDouble().toString(),
    "presence": {
      "events": [
        {
          "sender": "@alice:example.com",
          "type": "m.presence",
          "content": {"presence": "online"}
        }
      ]
    },
    "account_data": {
      "events": [
        {
          "content": {
            "global": {
              "content": [
                {
                  "actions": [
                    "notify",
                    {"set_tweak": "sound", "value": "default"},
                    {"set_tweak": "highlight"}
                  ],
                  "default": true,
                  "enabled": true,
                  "pattern": "alice",
                  "rule_id": ".m.rule.contains_user_name"
                }
              ],
              "override": [
                {
                  "actions": ["dont_notify"],
                  "conditions": [],
                  "default": true,
                  "enabled": false,
                  "rule_id": ".m.rule.master"
                },
                {
                  "actions": ["dont_notify"],
                  "conditions": [
                    {
                      "key": "content.msgtype",
                      "kind": "event_match",
                      "pattern": "m.notice"
                    }
                  ],
                  "default": true,
                  "enabled": true,
                  "rule_id": ".m.rule.suppress_notices"
                }
              ],
              "room": [
                {
                  "actions": ["dont_notify"],
                  "conditions": [
                    {
                      "key": "room_id",
                      "kind": "event_match",
                      "pattern": "!localpart:server.abc",
                    }
                  ],
                  "default": true,
                  "enabled": true,
                  "rule_id": "!localpart:server.abc"
                }
              ],
              "sender": [],
              "underride": [
                {
                  "actions": [
                    "notify",
                    {"set_tweak": "sound", "value": "ring"},
                    {"set_tweak": "highlight", "value": false}
                  ],
                  "conditions": [
                    {
                      "key": "type",
                      "kind": "event_match",
                      "pattern": "m.call.invite"
                    }
                  ],
                  "default": true,
                  "enabled": true,
                  "rule_id": ".m.rule.call"
                },
                {
                  "actions": [
                    "notify",
                    {"set_tweak": "sound", "value": "default"},
                    {"set_tweak": "highlight"}
                  ],
                  "conditions": [
                    {"kind": "contains_display_name"}
                  ],
                  "default": true,
                  "enabled": true,
                  "rule_id": ".m.rule.contains_display_name"
                },
                {
                  "actions": [
                    "notify",
                    {"set_tweak": "sound", "value": "default"},
                    {"set_tweak": "highlight", "value": false}
                  ],
                  "conditions": [
                    {"is": "2", "kind": "room_member_count"},
                    {
                      "key": "type",
                      "kind": "event_match",
                      "pattern": "m.room.message"
                    }
                  ],
                  "default": true,
                  "enabled": true,
                  "rule_id": ".m.rule.room_one_to_one"
                },
                {
                  "actions": [
                    "notify",
                    {"set_tweak": "sound", "value": "default"},
                    {"set_tweak": "highlight", "value": false}
                  ],
                  "conditions": [
                    {
                      "key": "type",
                      "kind": "event_match",
                      "pattern": "m.room.member"
                    },
                    {
                      "key": "content.membership",
                      "kind": "event_match",
                      "pattern": "invite"
                    },
                    {
                      "key": "state_key",
                      "kind": "event_match",
                      "pattern": "@alice:example.com"
                    }
                  ],
                  "default": true,
                  "enabled": true,
                  "rule_id": ".m.rule.invite_for_me"
                },
                {
                  "actions": [
                    "notify",
                    {"set_tweak": "highlight", "value": false}
                  ],
                  "conditions": [
                    {
                      "key": "type",
                      "kind": "event_match",
                      "pattern": "m.room.member"
                    }
                  ],
                  "default": true,
                  "enabled": true,
                  "rule_id": ".m.rule.member_event"
                },
                {
                  "actions": [
                    "notify",
                    {"set_tweak": "highlight", "value": false}
                  ],
                  "conditions": [
                    {
                      "key": "type",
                      "kind": "event_match",
                      "pattern": "m.room.message"
                    }
                  ],
                  "default": true,
                  "enabled": true,
                  "rule_id": ".m.rule.message"
                }
              ]
            }
          },
          "type": "m.push_rules"
        },
        {
          "type": "org.example.custom.config",
          "content": {"custom_config_key": "custom_config_value"}
        },
        {
          "content": {
            "@bob:example.com": [
              "!726s6s6q:example.com",
              "!hgfedcba:example.com"
            ]
          },
          "type": "m.direct"
        },
      ]
    },
    "to_device": {
      "events": [
        {
          "sender": "@alice:example.com",
          "type": "m.new_device",
          "content": {
            "device_id": "XYZABCDE",
            "rooms": ["!726s6s6q:example.com"]
          }
        }
      ]
    },
    "rooms": {
      "join": {
        "!726s6s6q:example.com": {
          "unread_notifications": {
            "highlight_count": 2,
            "notification_count": 2,
          },
          "state": {
            "events": [
              {
                "sender": "@alice:example.com",
                "type": "m.room.member",
                "state_key": "@alice:example.com",
                "content": {"membership": "join"},
                "origin_server_ts": 1417731086795,
                "event_id": "66697273743031:example.com"
              },
              {
                "sender": "@alice:example.com",
                "type": "m.room.canonical_alias",
                "content": {
                  "alias": "#famedlyContactDiscovery:fakeServer.notExisting"
                },
                "state_key": "",
                "origin_server_ts": 1417731086796,
                "event_id": "66697273743032:example.com"
              }
            ]
          },
          "timeline": {
            "events": [
              {
                "sender": "@bob:example.com",
                "type": "m.room.member",
                "state_key": "@bob:example.com",
                "content": {"membership": "join"},
                "prev_content": {"membership": "invite"},
                "origin_server_ts": 1417731086795,
                "event_id": "7365636s6r6432:example.com"
              },
              {
                "sender": "@alice:example.com",
                "type": "m.room.message",
                "txn_id": "1234",
                "content": {"body": "I am a fish", "msgtype": "m.text"},
                "origin_server_ts": 1417731086797,
                "event_id": "74686972643033:example.com"
              }
            ],
            "limited": true,
            "prev_batch": "t34-23535_0_0"
          },
          "ephemeral": {
            "events": [
              {
                "type": "m.typing",
                "content": {
                  "user_ids": ["@alice:example.com"]
                }
              },
              {
                "content": {
                  "7365636s6r6432:example.com": {
                    "m.read": {
                      "@alice:example.com": {"ts": 1436451550453}
                    }
                  }
                },
                "room_id": "!726s6s6q:example.com",
                "type": "m.receipt"
              }
            ]
          },
          "account_data": {
            "events": [
              {
                "type": "m.tag",
                "content": {
                  "tags": {
                    "work": {"order": 1}
                  }
                }
              },
              {
                "type": "org.example.custom.room.config",
                "content": {"custom_config_key": "custom_config_value"}
              }
            ]
          }
        }
      },
      "invite": {
        "!696r7674:example.com": {
          "invite_state": {
            "events": [
              {
                "sender": "@alice:example.com",
                "type": "m.room.name",
                "state_key": "",
                "content": {"name": "My Room Name"}
              },
              {
                "sender": "@alice:example.com",
                "type": "m.room.member",
                "state_key": "@bob:example.com",
                "content": {"membership": "invite"}
              }
            ]
          }
        }
      },
    }
  };

  static Map<String, dynamic> archiveSyncResponse = {
    "next_batch": Random().nextDouble().toString(),
    "presence": {"events": []},
    "account_data": {"events": []},
    "to_device": {"events": []},
    "rooms": {
      "join": {},
      "invite": {},
      "leave": {
        "!5345234234:example.com": {
          "timeline": {
            "events": [
              {
                "content": {
                  "body": "This is an example text message",
                  "msgtype": "m.text",
                  "format": "org.matrix.custom.html",
                  "formatted_body": "<b>This is an example text message</b>"
                },
                "type": "m.room.message",
                "event_id": "143273582443PhrSn:example.org",
                "room_id": "!5345234234:example.com",
                "sender": "@example:example.org",
                "origin_server_ts": 1432735824653,
                "unsigned": {"age": 1234}
              },
            ]
          },
          "state": {
            "events": [
              {
                "content": {"name": "The room name"},
                "type": "m.room.name",
                "event_id": "2143273582443PhrSn:example.org",
                "room_id": "!5345234234:example.com",
                "sender": "@example:example.org",
                "origin_server_ts": 1432735824653,
                "unsigned": {"age": 1234},
                "state_key": ""
              },
            ]
          },
          "account_data": {
            "events": [
              {
                "type": "test.type.data",
                "content": {"foo": "bar"},
              },
            ],
          },
        },
        "!5345234235:example.com": {
          "timeline": {"events": []},
          "state": {
            "events": [
              {
                "content": {"name": "The room name 2"},
                "type": "m.room.name",
                "event_id": "2143273582443PhrSn:example.org",
                "room_id": "!5345234235:example.com",
                "sender": "@example:example.org",
                "origin_server_ts": 1432735824653,
                "unsigned": {"age": 1234},
                "state_key": ""
              },
            ]
          }
        },
      },
    }
  };

  static final Map<String, Map<String, dynamic>> api = {
    "GET": {
      "/client/r0/profile/@getme:example.com": (var req) => {
            "avatar_url": "mxc://test",
            "displayname": "You got me",
          },
      "/client/r0/rooms/!localpart:server.abc/state/m.room.member/@getme:example.com":
          (var req) => {
                "avatar_url": "mxc://test",
                "displayname": "You got me",
              },
      "/client/r0/rooms/!localpart:server.abc/event/1234": (var req) => {
            "content": {
              "body": "This is an example text message",
              "msgtype": "m.text",
              "format": "org.matrix.custom.html",
              "formatted_body": "<b>This is an example text message</b>"
            },
            "type": "m.room.message",
            "event_id": "143273582443PhrSn:example.org",
            "room_id": "!localpart:server.abc",
            "sender": "@example:example.org",
            "origin_server_ts": 1432735824653,
            "unsigned": {"age": 1234}
          },
      "/client/r0/rooms/!1234:example.com/messages?from=1234&dir=b&limit=100&filter=%7B%22room%22:%7B%22state%22:%7B%22lazy_load_members%22:true%7D%7D%7D":
          (var req) => {
                "start": "t47429-4392820_219380_26003_2265",
                "end": "t47409-4357353_219380_26003_2265",
                "chunk": [
                  {
                    "content": {
                      "body": "This is an example text message",
                      "msgtype": "m.text",
                      "format": "org.matrix.custom.html",
                      "formatted_body": "<b>This is an example text message</b>"
                    },
                    "type": "m.room.message",
                    "event_id": "3143273582443PhrSn:example.org",
                    "room_id": "!1234:example.com",
                    "sender": "@example:example.org",
                    "origin_server_ts": 1432735824653,
                    "unsigned": {"age": 1234}
                  },
                  {
                    "content": {"name": "The room name"},
                    "type": "m.room.name",
                    "event_id": "2143273582443PhrSn:example.org",
                    "room_id": "!1234:example.com",
                    "sender": "@example:example.org",
                    "origin_server_ts": 1432735824653,
                    "unsigned": {"age": 1234},
                    "state_key": ""
                  },
                  {
                    "content": {
                      "body": "Gangnam Style",
                      "url": "mxc://example.org/a526eYUSFFxlgbQYZmo442",
                      "info": {
                        "thumbnail_url":
                            "mxc://example.org/FHyPlCeYUSFFxlgbQYZmoEoe",
                        "thumbnail_info": {
                          "mimetype": "image/jpeg",
                          "size": 46144,
                          "w": 300,
                          "h": 300
                        },
                        "w": 480,
                        "h": 320,
                        "duration": 2140786,
                        "size": 1563685,
                        "mimetype": "video/mp4"
                      },
                      "msgtype": "m.video"
                    },
                    "type": "m.room.message",
                    "event_id": "1143273582443PhrSn:example.org",
                    "room_id": "!1234:example.com",
                    "sender": "@example:example.org",
                    "origin_server_ts": 1432735824653,
                    "unsigned": {"age": 1234}
                  }
                ]
              },
      "/client/versions": (var req) => {
            "versions": [
              "r0.0.1",
              "r0.1.0",
              "r0.2.0",
              "r0.3.0",
              "r0.4.0",
              "r0.5.0"
            ],
            "unstable_features": {"m.lazy_load_members": true},
          },
      "/client/r0/login": (var req) => {
            "flows": [
              {"type": "m.login.password"}
            ]
          },
      "/client/r0/rooms/!726s6s6q:example.com/members": (var req) => {
            "chunk": [
              {
                "content": {
                  "membership": "join",
                  "avatar_url": "mxc://example.org/SEsfnsuifSDFSSEF",
                  "displayname": "Alice Margatroid"
                },
                "type": "m.room.member",
                "event_id": "§143273582443PhrSn:example.org",
                "room_id": "!636q39766251:example.com",
                "sender": "@alice:example.org",
                "origin_server_ts": 1432735824653,
                "unsigned": {"age": 1234},
                "state_key": "@alice:example.org"
              }
            ]
          },
      "/client/r0/rooms/!localpart:server.abc/members": (var req) => {
            "chunk": [
              {
                "content": {
                  "membership": "join",
                  "avatar_url": "mxc://example.org/SEsfnsuifSDFSSEF",
                  "displayname": "Alice Margatroid"
                },
                "type": "m.room.member",
                "event_id": "§143273582443PhrSn:example.org",
                "room_id": "!636q39766251:example.com",
                "sender": "@example:example.org",
                "origin_server_ts": 1432735824653,
                "unsigned": {"age": 1234},
                "state_key": "@alice:example.org"
              }
            ]
          },
      "/client/r0/pushrules/": (var req) => {
            "global": {
              "content": [
                {
                  "actions": [
                    "notify",
                    {"set_tweak": "sound", "value": "default"},
                    {"set_tweak": "highlight"}
                  ],
                  "default": true,
                  "enabled": true,
                  "pattern": "alice",
                  "rule_id": ".m.rule.contains_user_name"
                }
              ],
              "override": [
                {
                  "actions": ["dont_notify"],
                  "conditions": [],
                  "default": true,
                  "enabled": false,
                  "rule_id": ".m.rule.master"
                },
                {
                  "actions": ["dont_notify"],
                  "conditions": [
                    {
                      "key": "content.msgtype",
                      "kind": "event_match",
                      "pattern": "m.notice"
                    }
                  ],
                  "default": true,
                  "enabled": true,
                  "rule_id": ".m.rule.suppress_notices"
                }
              ],
              "room": [],
              "sender": [],
              "underride": [
                {
                  "actions": [
                    "notify",
                    {"set_tweak": "sound", "value": "ring"},
                    {"set_tweak": "highlight", "value": false}
                  ],
                  "conditions": [
                    {
                      "key": "type",
                      "kind": "event_match",
                      "pattern": "m.call.invite"
                    }
                  ],
                  "default": true,
                  "enabled": true,
                  "rule_id": ".m.rule.call"
                },
                {
                  "actions": [
                    "notify",
                    {"set_tweak": "sound", "value": "default"},
                    {"set_tweak": "highlight"}
                  ],
                  "conditions": [
                    {"kind": "contains_display_name"}
                  ],
                  "default": true,
                  "enabled": true,
                  "rule_id": ".m.rule.contains_display_name"
                },
                {
                  "actions": [
                    "notify",
                    {"set_tweak": "sound", "value": "default"},
                    {"set_tweak": "highlight", "value": false}
                  ],
                  "conditions": [
                    {"is": "2", "kind": "room_member_count"}
                  ],
                  "default": true,
                  "enabled": true,
                  "rule_id": ".m.rule.room_one_to_one"
                },
                {
                  "actions": [
                    "notify",
                    {"set_tweak": "sound", "value": "default"},
                    {"set_tweak": "highlight", "value": false}
                  ],
                  "conditions": [
                    {
                      "key": "type",
                      "kind": "event_match",
                      "pattern": "m.room.member"
                    },
                    {
                      "key": "content.membership",
                      "kind": "event_match",
                      "pattern": "invite"
                    },
                    {
                      "key": "state_key",
                      "kind": "event_match",
                      "pattern": "@alice:example.com"
                    }
                  ],
                  "default": true,
                  "enabled": true,
                  "rule_id": ".m.rule.invite_for_me"
                },
                {
                  "actions": [
                    "notify",
                    {"set_tweak": "highlight", "value": false}
                  ],
                  "conditions": [
                    {
                      "key": "type",
                      "kind": "event_match",
                      "pattern": "m.room.member"
                    }
                  ],
                  "default": true,
                  "enabled": true,
                  "rule_id": ".m.rule.member_event"
                },
                {
                  "actions": [
                    "notify",
                    {"set_tweak": "highlight", "value": false}
                  ],
                  "conditions": [
                    {
                      "key": "type",
                      "kind": "event_match",
                      "pattern": "m.room.message"
                    }
                  ],
                  "default": true,
                  "enabled": true,
                  "rule_id": ".m.rule.message"
                }
              ]
            }
          },
      "/client/r0/sync?filter=%7B%22room%22:%7B%22include_leave%22:true,%22timeline%22:%7B%22limit%22:10%7D%7D%7D&timeout=0":
          (var req) => archiveSyncResponse,
      "/client/r0/sync?filter=%7B%22room%22:%7B%22state%22:%7B%22lazy_load_members%22:true%7D%7D%7D":
          (var req) => syncResponse,
    },
    "POST": {
      "/client/r0/login": (var req) => {
            "user_id": "@test:fakeServer.notExisting",
            "access_token": "abc123",
            "device_id": "GHTYAJCE"
          },
      "/media/r0/upload?filename=file.jpeg": (var req) =>
          {"content_uri": "mxc://example.com/AQwafuaFswefuhsfAFAgsw"},
      "/client/r0/logout": (var reqI) => {},
      "/client/r0/pushers/set": (var reqI) => {},
      "/client/r0/join/1234": (var reqI) => {"room_id": "1234"},
      "/client/r0/logout/all": (var reqI) => {},
      "/client/r0/createRoom": (var reqI) => {
            "room_id": "!1234:fakeServer.notExisting",
          },
      "/client/r0/rooms/!localpart:server.abc/read_markers": (var reqI) => {},
      "/client/r0/rooms/!localpart:server.abc/kick": (var reqI) => {},
      "/client/r0/rooms/!localpart:server.abc/ban": (var reqI) => {},
      "/client/r0/rooms/!localpart:server.abc/unban": (var reqI) => {},
      "/client/r0/rooms/!localpart:server.abc/invite": (var reqI) => {},
    },
    "PUT": {
      "/client/r0/rooms/!localpart:server.abc/send/m.room.message/testtxid":
          (var reqI) => {
                "event_id": "42",
              },
      "/client/r0/rooms/!1234:example.com/send/m.room.message/1234":
          (var reqI) => {
                "event_id": "42",
              },
      "/client/r0/profile/@test:fakeServer.notExisting/avatar_url":
          (var reqI) => {},
      "/client/r0/rooms/!localpart:server.abc/state/m.room.avatar/":
          (var reqI) => {"event_id": "YUwRidLecu:example.com"},
      "/client/r0/rooms/!localpart:server.abc/state/m.room.name": (var reqI) =>
          {
            "event_id": "42",
          },
      "/client/r0/rooms/!localpart:server.abc/state/m.room.topic": (var reqI) =>
          {
            "event_id": "42",
          },
      "/client/r0/rooms/!localpart:server.abc/state/m.room.power_levels":
          (var reqI) => {
                "event_id": "42",
              },
      "/client/r0/user/@test:fakeServer.notExisting/account_data/m.direct":
          (var reqI) => {},
    },
    "DELETE": {
      "/unknown/token": (var req) => {"errcode": "M_UNKNOWN_TOKEN"},
    },
  };
}
