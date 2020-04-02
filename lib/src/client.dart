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

import 'dart:async';
import 'dart:core';

import 'package:canonical_json/canonical_json.dart';
import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/src/account_data.dart';
import 'package:famedlysdk/src/presence.dart';
import 'package:famedlysdk/src/store_api.dart';
import 'package:famedlysdk/src/sync/user_update.dart';
import 'package:famedlysdk/src/utils/device_keys_list.dart';
import 'package:famedlysdk/src/utils/matrix_file.dart';
import 'package:famedlysdk/src/utils/open_id_credentials.dart';
import 'package:famedlysdk/src/utils/public_rooms_response.dart';
import 'package:famedlysdk/src/utils/room_key_request.dart';
import 'package:famedlysdk/src/utils/session_key.dart';
import 'package:famedlysdk/src/utils/to_device_event.dart';
import 'package:famedlysdk/src/utils/turn_server_credentials.dart';
import 'package:famedlysdk/src/utils/user_device.dart';
import 'package:olm/olm.dart' as olm;
import 'package:pedantic/pedantic.dart';
import 'room.dart';
import 'event.dart';
import 'user.dart';
import 'utils/profile.dart';
import 'dart:convert';
import 'package:famedlysdk/src/room.dart';
import 'package:http/http.dart' as http;
import 'package:mime_type/mime_type.dart';
import 'sync/event_update.dart';
import 'sync/room_update.dart';
import 'sync/user_update.dart';
import 'utils/matrix_exception.dart';

typedef RoomSorter = int Function(Room a, Room b);

enum HTTPType { GET, POST, PUT, DELETE }

enum LoginState { logged, loggedOut }

/// Represents a Matrix client to communicate with a
/// [Matrix](https://matrix.org) homeserver and is the entry point for this
/// SDK.
class Client {
  /// Handles the connection for this client.
  @deprecated
  Client get connection => this;

  /// Optional persistent store for all data.
  ExtendedStoreAPI get store => (storeAPI?.extended ?? false) ? storeAPI : null;

  StoreAPI storeAPI;

  Client(this.clientName, {this.debug = false, this.storeAPI}) {
    onLoginStateChanged.stream.listen((loginState) {
      print('LoginState: ${loginState.toString()}');
    });
  }

  /// Whether debug prints should be displayed.
  final bool debug;

  /// The required name for this client.
  final String clientName;

  /// The homeserver this client is communicating with.
  String get homeserver => _homeserver;
  String _homeserver;

  /// The Matrix ID of the current logged user.
  String get userID => _userID;
  String _userID;

  /// This is the access token for the matrix client. When it is undefined, then
  /// the user needs to sign in first.
  String get accessToken => _accessToken;
  String _accessToken;

  /// This points to the position in the synchronization history.
  String prevBatch;

  /// The device ID is an unique identifier for this device.
  String get deviceID => _deviceID;
  String _deviceID;

  /// The device name is a human readable identifier for this device.
  String get deviceName => _deviceName;
  String _deviceName;

  /// Which version of the matrix specification does this server support?
  List<String> get matrixVersions => _matrixVersions;
  List<String> _matrixVersions;

  /// Wheither the server supports lazy load members.
  bool get lazyLoadMembers => _lazyLoadMembers;
  bool _lazyLoadMembers = false;

  /// Returns the current login state.
  bool isLogged() => accessToken != null;

  /// A list of all rooms the user is participating or invited.
  List<Room> get rooms => _rooms;
  List<Room> _rooms = [];

  olm.Account _olmAccount;

  /// Returns the base64 encoded keys to store them in a store.
  /// This String should **never** leave the device!
  String get pickledOlmAccount =>
      encryptionEnabled ? _olmAccount.pickle(userID) : null;

  /// Whether this client supports end-to-end encryption using olm.
  bool get encryptionEnabled => _olmAccount != null;

  /// Whether this client is able to encrypt and decrypt files.
  bool get fileEncryptionEnabled => true;

  /// Warning! This endpoint is for testing only!
  set rooms(List<Room> newList) {
    print('Warning! This endpoint is for testing only!');
    _rooms = newList;
  }

  /// Key/Value store of account data.
  Map<String, AccountData> accountData = {};

  /// Presences of users by a given matrix ID
  Map<String, Presence> presences = {};

  int _timeoutFactor = 1;

  Room getRoomByAlias(String alias) {
    for (var i = 0; i < rooms.length; i++) {
      if (rooms[i].canonicalAlias == alias) return rooms[i];
    }
    return null;
  }

  Room getRoomById(String id) {
    for (var j = 0; j < rooms.length; j++) {
      if (rooms[j].id == id) return rooms[j];
    }
    return null;
  }

  void handleUserUpdate(UserUpdate userUpdate) {
    if (userUpdate.type == 'account_data') {
      var newAccountData = AccountData.fromJson(userUpdate.content);
      accountData[newAccountData.typeKey] = newAccountData;
      if (onAccountData != null) onAccountData.add(newAccountData);
    }
    if (userUpdate.type == 'presence') {
      var newPresence = Presence.fromJson(userUpdate.content);
      presences[newPresence.sender] = newPresence;
      if (onPresence != null) onPresence.add(newPresence);
    }
  }

  Map<String, dynamic> get directChats =>
      accountData['m.direct'] != null ? accountData['m.direct'].content : {};

  /// Returns the (first) room ID from the store which is a private chat with the user [userId].
  /// Returns null if there is none.
  String getDirectChatFromUserId(String userId) {
    if (accountData['m.direct'] != null &&
        accountData['m.direct'].content[userId] is List<dynamic> &&
        accountData['m.direct'].content[userId].length > 0) {
      if (getRoomById(accountData['m.direct'].content[userId][0]) != null) {
        return accountData['m.direct'].content[userId][0];
      }
      (accountData['m.direct'].content[userId] as List<dynamic>)
          .remove(accountData['m.direct'].content[userId][0]);
      jsonRequest(
          type: HTTPType.PUT,
          action: '/client/r0/user/${userID}/account_data/m.direct',
          data: directChats);
      return getDirectChatFromUserId(userId);
    }
    for (var i = 0; i < rooms.length; i++) {
      if (rooms[i].membership == Membership.invite &&
          rooms[i].states[userID]?.senderId == userId &&
          rooms[i].states[userID].content['is_direct'] == true) {
        return rooms[i].id;
      }
    }
    return null;
  }

  /// Checks the supported versions of the Matrix protocol and the supported
  /// login types. Returns false if the server is not compatible with the
  /// client. Automatically sets [matrixVersions] and [lazyLoadMembers].
  /// Throws FormatException, TimeoutException and MatrixException on error.
  Future<bool> checkServer(serverUrl) async {
    try {
      _homeserver = serverUrl;
      final versionResp =
          await jsonRequest(type: HTTPType.GET, action: '/client/versions');

      final versions = List<String>.from(versionResp['versions']);

      for (var i = 0; i < versions.length; i++) {
        if (versions[i] == 'r0.5.0') {
          break;
        } else if (i == versions.length - 1) {
          return false;
        }
      }

      _matrixVersions = versions;

      if (versionResp.containsKey('unstable_features') &&
          versionResp['unstable_features'].containsKey('m.lazy_load_members')) {
        _lazyLoadMembers = versionResp['unstable_features']
                ['m.lazy_load_members']
            ? true
            : false;
      }

      final loginResp =
          await jsonRequest(type: HTTPType.GET, action: '/client/r0/login');

      final List<dynamic> flows = loginResp['flows'];

      for (var i = 0; i < flows.length; i++) {
        if (flows[i].containsKey('type') &&
            flows[i]['type'] == 'm.login.password') {
          break;
        } else if (i == flows.length - 1) {
          return false;
        }
      }
      return true;
    } catch (_) {
      _homeserver = _matrixVersions = null;
      rethrow;
    }
  }

  /// Checks to see if a username is available, and valid, for the server.
  /// You have to call [checkServer] first to set a homeserver.
  Future<bool> usernameAvailable(String username) async {
    final response = await jsonRequest(
      type: HTTPType.GET,
      action: '/client/r0/register/available?username=$username',
    );
    return response['available'];
  }

  /// Checks to see if a username is available, and valid, for the server.
  /// Returns the fully-qualified Matrix user ID (MXID) that has been registered.
  /// You have to call [checkServer] first to set a homeserver.
  Future<Map<String, dynamic>> register({
    String kind,
    String username,
    String password,
    Map<String, dynamic> auth,
    String deviceId,
    String initialDeviceDisplayName,
    bool inhibitLogin,
  }) async {
    final action = '/client/r0/register' + (kind != null ? '?kind=$kind' : '');
    var data = <String, dynamic>{};
    if (username != null) data['username'] = username;
    if (password != null) data['password'] = password;
    if (auth != null) data['auth'] = auth;
    if (deviceId != null) data['device_id'] = deviceId;
    if (initialDeviceDisplayName != null) {
      data['initial_device_display_name'] = initialDeviceDisplayName;
    }
    if (inhibitLogin != null) data['inhibit_login'] = inhibitLogin;
    final response =
        await jsonRequest(type: HTTPType.POST, action: action, data: data);

    // Connect if there is an access token in the response.
    if (response.containsKey('access_token') &&
        response.containsKey('device_id') &&
        response.containsKey('user_id')) {
      await connect(
          newToken: response['access_token'],
          newUserID: response['user_id'],
          newHomeserver: homeserver,
          newDeviceName: initialDeviceDisplayName ?? '',
          newDeviceID: response['device_id'],
          newMatrixVersions: matrixVersions,
          newLazyLoadMembers: lazyLoadMembers);
    }
    return response;
  }

  /// Handles the login and allows the client to call all APIs which require
  /// authentication. Returns false if the login was not successful. Throws
  /// MatrixException if login was not successful.
  /// You have to call [checkServer] first to set a homeserver.
  Future<bool> login(
    String username,
    String password, {
    String initialDeviceDisplayName,
    String deviceId,
  }) async {
    var data = <String, dynamic>{
      'type': 'm.login.password',
      'user': username,
      'identifier': {
        'type': 'm.id.user',
        'user': username,
      },
      'password': password,
    };
    if (deviceId != null) data['device_id'] = deviceId;
    if (initialDeviceDisplayName != null) {
      data['initial_device_display_name'] = initialDeviceDisplayName;
    }

    final loginResp = await jsonRequest(
        type: HTTPType.POST, action: '/client/r0/login', data: data);

    if (loginResp.containsKey('user_id') &&
        loginResp.containsKey('access_token') &&
        loginResp.containsKey('device_id')) {
      await connect(
        newToken: loginResp['access_token'],
        newUserID: loginResp['user_id'],
        newHomeserver: homeserver,
        newDeviceName: initialDeviceDisplayName ?? '',
        newDeviceID: loginResp['device_id'],
        newMatrixVersions: matrixVersions,
        newLazyLoadMembers: lazyLoadMembers,
      );
      return true;
    }
    return false;
  }

  /// Sends a logout command to the homeserver and clears all local data,
  /// including all persistent data from the store.
  Future<void> logout() async {
    try {
      await jsonRequest(type: HTTPType.POST, action: '/client/r0/logout');
    } catch (exception) {
      rethrow;
    } finally {
      await clear();
    }
  }

  /// Returns the user's own displayname and avatar url. In Matrix it is possible that
  /// one user can have different displaynames and avatar urls in different rooms. So
  /// this endpoint first checks if the profile is the same in all rooms. If not, the
  /// profile will be requested from the homserver.
  Future<Profile> get ownProfile async {
    if (rooms.isNotEmpty) {
      var profileSet = <Profile>{};
      for (var room in rooms) {
        final user = room.getUserByMXIDSync(userID);
        profileSet.add(Profile.fromJson(user.content));
      }
      if (profileSet.length == 1) return profileSet.first;
    }
    return getProfileFromUserId(userID);
  }

  /// Get the combined profile information for this user. This API may be used to
  /// fetch the user's own profile information or other users; either locally
  /// or on remote homeservers.
  Future<Profile> getProfileFromUserId(String userId) async {
    final dynamic resp = await jsonRequest(
        type: HTTPType.GET, action: '/client/r0/profile/${userId}');
    return Profile.fromJson(resp);
  }

  Future<List<Room>> get archive async {
    var archiveList = <Room>[];
    var syncFilters = '{"room":{"include_leave":true,"timeline":{"limit":10}}}';
    var action = '/client/r0/sync?filter=$syncFilters&timeout=0';
    final sync = await jsonRequest(type: HTTPType.GET, action: action);
    if (sync['rooms']['leave'] is Map<String, dynamic>) {
      for (var entry in sync['rooms']['leave'].entries) {
        final String id = entry.key;
        final dynamic room = entry.value;
        var leftRoom = Room(
            id: id,
            membership: Membership.leave,
            client: this,
            roomAccountData: {},
            mHeroes: []);
        if (room['account_data'] is Map<String, dynamic> &&
            room['account_data']['events'] is List<dynamic>) {
          for (dynamic event in room['account_data']['events']) {
            leftRoom.roomAccountData[event['type']] =
                RoomAccountData.fromJson(event, leftRoom);
          }
        }
        if (room['timeline'] is Map<String, dynamic> &&
            room['timeline']['events'] is List<dynamic>) {
          for (dynamic event in room['timeline']['events']) {
            leftRoom.setState(Event.fromJson(event, leftRoom));
          }
        }
        if (room['state'] is Map<String, dynamic> &&
            room['state']['events'] is List<dynamic>) {
          for (dynamic event in room['state']['events']) {
            leftRoom.setState(Event.fromJson(event, leftRoom));
          }
        }
        archiveList.add(leftRoom);
      }
    }
    return archiveList;
  }

  /// This API starts a user participating in a particular room, if that user is allowed to participate in that room.
  /// After this call, the client is allowed to see all current state events in the room, and all subsequent events
  /// associated with the room until the user leaves the room.
  Future<dynamic> joinRoomById(String roomIdOrAlias) async {
    return await jsonRequest(
        type: HTTPType.POST, action: '/client/r0/join/$roomIdOrAlias');
  }

  /// Loads the contact list for this user excluding the user itself.
  /// Currently the contacts are found by discovering the contacts of
  /// the famedlyContactDiscovery room, which is
  /// defined by the autojoin room feature in Synapse.
  Future<List<User>> loadFamedlyContacts() async {
    var contacts = <User>[];
    var contactDiscoveryRoom =
        getRoomByAlias('#famedlyContactDiscovery:${userID.domain}');
    if (contactDiscoveryRoom != null) {
      contacts = await contactDiscoveryRoom.requestParticipants();
    } else {
      var userMap = <String, bool>{};
      for (var i = 0; i < rooms.length; i++) {
        var roomUsers = rooms[i].getParticipants();
        for (var j = 0; j < roomUsers.length; j++) {
          if (userMap[roomUsers[j].id] != true) contacts.add(roomUsers[j]);
          userMap[roomUsers[j].id] = true;
        }
      }
    }
    return contacts;
  }

  @Deprecated('Please use [createRoom] instead!')
  Future<String> createGroup(List<User> users) => createRoom(invite: users);

  /// Creates a new group chat and invites the given Users and returns the new
  /// created room ID. If [params] are provided, invite will be ignored. For the
  /// moment please look at https://matrix.org/docs/spec/client_server/r0.5.0#post-matrix-client-r0-createroom
  /// to configure [params].
  Future<String> createRoom(
      {List<User> invite, Map<String, dynamic> params}) async {
    var inviteIDs = <String>[];
    if (params == null && invite != null) {
      for (var i = 0; i < invite.length; i++) {
        inviteIDs.add(invite[i].id);
      }
    }

    try {
      final dynamic resp = await jsonRequest(
          type: HTTPType.POST,
          action: '/client/r0/createRoom',
          data: params ??
              {
                'invite': inviteIDs,
              });
      return resp['room_id'];
    } catch (e) {
      rethrow;
    }
  }

  /// Changes the user's displayname.
  Future<void> setDisplayname(String displayname) async {
    await jsonRequest(
        type: HTTPType.PUT,
        action: '/client/r0/profile/$userID/displayname',
        data: {'displayname': displayname});
    return;
  }

  /// Uploads a new user avatar for this user.
  Future<void> setAvatar(MatrixFile file) async {
    final uploadResp = await upload(file);
    await jsonRequest(
        type: HTTPType.PUT,
        action: '/client/r0/profile/$userID/avatar_url',
        data: {'avatar_url': uploadResp});
    return;
  }

  /// Get credentials for the client to use when initiating calls.
  Future<TurnServerCredentials> getTurnServerCredentials() async {
    final response = await jsonRequest(
      type: HTTPType.GET,
      action: '/client/r0/voip/turnServer',
    );
    return TurnServerCredentials.fromJson(response);
  }

  /// Fetches the pushrules for the logged in user.
  /// These are needed for notifications on Android
  @Deprecated('Use [pushRules] instead.')
  Future<PushRules> getPushrules() async {
    final dynamic resp = await jsonRequest(
      type: HTTPType.GET,
      action: '/client/r0/pushrules/',
    );

    return PushRules.fromJson(resp);
  }

  /// Returns the push rules for the logged in user.
  PushRules get pushRules => accountData.containsKey('m.push_rules')
      ? PushRules.fromJson(accountData['m.push_rules'].content)
      : null;

  /// This endpoint allows the creation, modification and deletion of pushers for this user ID.
  Future<void> setPushers(String pushKey, String kind, String appId,
      String appDisplayName, String deviceDisplayName, String lang, String url,
      {bool append, String profileTag, String format}) async {
    var data = <String, dynamic>{
      'lang': lang,
      'kind': kind,
      'app_display_name': appDisplayName,
      'device_display_name': deviceDisplayName,
      'profile_tag': profileTag,
      'app_id': appId,
      'pushkey': pushKey,
      'data': {'url': url}
    };

    if (format != null) data['data']['format'] = format;
    if (profileTag != null) data['profile_tag'] = profileTag;
    if (append != null) data['append'] = append;

    await jsonRequest(
      type: HTTPType.POST,
      action: '/client/r0/pushers/set',
      data: data,
    );
    return;
  }

  static String syncFilters = '{"room":{"state":{"lazy_load_members":true}}}';
  static const List<String> supportedDirectEncryptionAlgorithms = [
    'm.olm.v1.curve25519-aes-sha2'
  ];
  static const List<String> supportedGroupEncryptionAlgorithms = [
    'm.megolm.v1.aes-sha2'
  ];

  http.Client httpClient = http.Client();

  /// The newEvent signal is the most important signal in this concept. Every time
  /// the app receives a new synchronization, this event is called for every signal
  /// to update the GUI. For example, for a new message, it is called:
  /// onRoomEvent( "m.room.message", "!chat_id:server.com", "timeline", {sender: "@bob:server.com", body: "Hello world"} )
  final StreamController<EventUpdate> onEvent = StreamController.broadcast();

  /// Outside of the events there are updates for the global chat states which
  /// are handled by this signal:
  final StreamController<RoomUpdate> onRoomUpdate =
      StreamController.broadcast();

  /// Outside of rooms there are account updates like account_data or presences.
  final StreamController<UserUpdate> onUserEvent = StreamController.broadcast();

  /// The onToDeviceEvent is called when there comes a new to device event. It is
  /// already decrypted if necessary.
  final StreamController<ToDeviceEvent> onToDeviceEvent =
      StreamController.broadcast();

  /// Called when the login state e.g. user gets logged out.
  final StreamController<LoginState> onLoginStateChanged =
      StreamController.broadcast();

  /// Synchronization erros are coming here.
  final StreamController<MatrixException> onError =
      StreamController.broadcast();

  /// This is called once, when the first sync has received.
  final StreamController<bool> onFirstSync = StreamController.broadcast();

  /// When a new sync response is coming in, this gives the complete payload.
  final StreamController<dynamic> onSync = StreamController.broadcast();

  /// Callback will be called on presences.
  final StreamController<Presence> onPresence = StreamController.broadcast();

  /// Callback will be called on account data updates.
  final StreamController<AccountData> onAccountData =
      StreamController.broadcast();

  /// Will be called on call invites.
  final StreamController<Event> onCallInvite = StreamController.broadcast();

  /// Will be called on call hangups.
  final StreamController<Event> onCallHangup = StreamController.broadcast();

  /// Will be called on call candidates.
  final StreamController<Event> onCallCandidates = StreamController.broadcast();

  /// Will be called on call answers.
  final StreamController<Event> onCallAnswer = StreamController.broadcast();

  /// Will be called when another device is requesting session keys for a room.
  final StreamController<RoomKeyRequest> onRoomKeyRequest =
      StreamController.broadcast();

  /// Matrix synchronisation is done with https long polling. This needs a
  /// timeout which is usually 30 seconds.
  int syncTimeoutSec = 30;

  /// How long should the app wait until it retrys the synchronisation after
  /// an error?
  int syncErrorTimeoutSec = 3;

  /// Sets the user credentials and starts the synchronisation.
  ///
  /// Before you can connect you need at least an [accessToken], a [homeserver],
  /// a [userID], a [deviceID], and a [deviceName].
  ///
  /// You get this informations
  /// by logging in to your Matrix account, using the [login API](https://matrix.org/docs/spec/client_server/r0.4.0.html#post-matrix-client-r0-login).
  ///
  /// To log in you can use [jsonRequest()] after you have set the [homeserver]
  /// to a valid url. For example:
  ///
  /// ```
  /// final resp = await matrix
  ///          .jsonRequest(type: HTTPType.POST, action: "/client/r0/login", data: {
  ///        "type": "m.login.password",
  ///        "user": "test",
  ///        "password": "1234",
  ///        "initial_device_display_name": "Fluffy Matrix Client"
  ///      });
  /// ```
  ///
  /// Returns:
  ///
  /// ```
  /// {
  ///  "user_id": "@cheeky_monkey:matrix.org",
  ///  "access_token": "abc123",
  ///  "device_id": "GHTYAJCE"
  /// }
  /// ```
  ///
  /// Sends [LoginState.logged] to [onLoginStateChanged].
  void connect({
    String newToken,
    String newHomeserver,
    String newUserID,
    String newDeviceName,
    String newDeviceID,
    List<String> newMatrixVersions,
    bool newLazyLoadMembers,
    String newPrevBatch,
    String newOlmAccount,
  }) async {
    _accessToken = newToken;
    _homeserver = newHomeserver;
    _userID = newUserID;
    _deviceID = newDeviceID;
    _deviceName = newDeviceName;
    _matrixVersions = newMatrixVersions;
    _lazyLoadMembers = newLazyLoadMembers;
    prevBatch = newPrevBatch;

    // Try to create a new olm account or restore a previous one.
    if (newOlmAccount == null) {
      try {
        await olm.init();
        _olmAccount = olm.Account();
        _olmAccount.create();
        if (await _uploadKeys(uploadDeviceKeys: true) == false) {
          throw ('Upload key failed');
        }
      } catch (_) {
        _olmAccount = null;
      }
    } else {
      try {
        await olm.init();
        _olmAccount = olm.Account();
        _olmAccount.unpickle(userID, newOlmAccount);
      } catch (_) {
        _olmAccount = null;
      }
    }

    if (storeAPI != null) {
      await storeAPI.storeClient();
      _userDeviceKeys = await storeAPI.getUserDeviceKeys();
      final String olmSessionPickleString =
          await storeAPI.getItem('/clients/$userID/olm-sessions');
      if (olmSessionPickleString != null) {
        final Map<String, dynamic> pickleMap =
            json.decode(olmSessionPickleString);
        for (var entry in pickleMap.entries) {
          for (String pickle in entry.value) {
            _olmSessions[entry.key] = [];
            try {
              var session = olm.Session();
              session.unpickle(userID, pickle);
              _olmSessions[entry.key].add(session);
            } catch (e) {
              print('[LibOlm] Could not unpickle olm session: ' + e.toString());
            }
          }
        }
      }
      if (store != null) {
        _rooms = await store.getRoomList(onlyLeft: false);
        _sortRooms();
        accountData = await store.getAccountData();
        presences = await store.getPresences();
      }
    }

    _userEventSub ??= onUserEvent.stream.listen(handleUserUpdate);

    onLoginStateChanged.add(LoginState.logged);

    return _sync();
  }

  StreamSubscription _userEventSub;

  /// Resets all settings and stops the synchronisation.
  void clear() {
    olmSessions.values.forEach((List<olm.Session> sessions) {
      sessions.forEach((olm.Session session) => session?.free());
    });
    rooms.forEach((Room room) {
      room.clearOutboundGroupSession(wipe: true);
      room.sessionKeys.values.forEach((SessionKey sessionKey) {
        sessionKey.inboundGroupSession?.free();
      });
    });
    _olmAccount?.free();
    storeAPI?.clear();
    _accessToken = _homeserver = _userID = _deviceID =
        _deviceName = _matrixVersions = _lazyLoadMembers = prevBatch = null;
    onLoginStateChanged.add(LoginState.loggedOut);
  }

  /// Used for all Matrix json requests using the [c2s API](https://matrix.org/docs/spec/client_server/r0.4.0.html).
  ///
  /// Throws: TimeoutException, FormatException, MatrixException
  ///
  /// You must first call [this.connect()] or set [this.homeserver] before you can use
  /// this! For example to send a message to a Matrix room with the id
  /// '!fjd823j:example.com' you call:
  ///
  /// ```
  /// final resp = await jsonRequest(
  ///   type: HTTPType.PUT,
  ///   action: "/r0/rooms/!fjd823j:example.com/send/m.room.message/$txnId",
  ///   data: {
  ///     "msgtype": "m.text",
  ///     "body": "hello"
  ///   }
  ///  );
  /// ```
  ///
  Future<Map<String, dynamic>> jsonRequest(
      {HTTPType type,
      String action,
      dynamic data = '',
      int timeout,
      String contentType = 'application/json'}) async {
    if (isLogged() == false && homeserver == null) {
      throw ('No homeserver specified.');
    }
    timeout ??= (_timeoutFactor * syncTimeoutSec) + 5;
    dynamic json;
    if (data is Map) data.removeWhere((k, v) => v == null);
    (!(data is String)) ? json = jsonEncode(data) : json = data;
    if (data is List<int> || action.startsWith('/media/r0/upload')) json = data;

    final url = '${homeserver}/_matrix${action}';

    var headers = <String, String>{};
    if (type == HTTPType.PUT || type == HTTPType.POST) {
      headers['Content-Type'] = contentType;
    }
    if (isLogged()) {
      headers['Authorization'] = 'Bearer ${accessToken}';
    }

    if (debug) {
      print(
          "[REQUEST ${type.toString().split('.').last}] Action: $action, Data: ${jsonEncode(data)}");
    }

    http.Response resp;
    var jsonResp = <String, dynamic>{};
    try {
      switch (type.toString().split('.').last) {
        case 'GET':
          resp = await httpClient.get(url, headers: headers).timeout(
                Duration(seconds: timeout),
                onTimeout: () => null,
              );
          break;
        case 'POST':
          resp =
              await httpClient.post(url, body: json, headers: headers).timeout(
                    Duration(seconds: timeout),
                    onTimeout: () => null,
                  );
          break;
        case 'PUT':
          resp =
              await httpClient.put(url, body: json, headers: headers).timeout(
                    Duration(seconds: timeout),
                    onTimeout: () => null,
                  );
          break;
        case 'DELETE':
          resp = await httpClient.delete(url, headers: headers).timeout(
                Duration(seconds: timeout),
                onTimeout: () => null,
              );
          break;
      }
      if (resp == null) {
        throw TimeoutException;
      }
      jsonResp = jsonDecode(String.fromCharCodes(resp.body.runes))
          as Map<String, dynamic>; // May throw FormatException

      if (resp.statusCode >= 400 && resp.statusCode < 500) {
        // The server has responsed with an matrix related error.
        var exception = MatrixException(resp);
        if (exception.error == MatrixError.M_UNKNOWN_TOKEN) {
          // The token is no longer valid. Need to sign off....
          onError.add(exception);
          clear();
        }

        throw exception;
      }

      if (debug) print('[RESPONSE] ${jsonResp.toString()}');
    } on ArgumentError catch (exception) {
      print(exception);
      // Ignore this error
    } on TimeoutException catch (_) {
      _timeoutFactor *= 2;
      rethrow;
    } catch (_) {
      print(_);
      rethrow;
    }

    return jsonResp;
  }

  /// Uploads a file with the name [fileName] as base64 encoded to the server
  /// and returns the mxc url as a string.
  Future<String> upload(MatrixFile file, {String contentType}) async {
    // For testing
    if (homeserver.toLowerCase() == 'https://fakeserver.notexisting') {
      return 'mxc://example.com/AQwafuaFswefuhsfAFAgsw';
    }
    var headers = <String, String>{};
    headers['Authorization'] = 'Bearer $accessToken';
    headers['Content-Type'] = contentType ?? mime(file.path);
    var fileName = Uri.encodeFull(file.path.split('/').last.toLowerCase());
    final url = '$homeserver/_matrix/media/r0/upload?filename=$fileName';
    final streamedRequest = http.StreamedRequest('POST', Uri.parse(url))
      ..headers.addAll(headers);
    streamedRequest.contentLength = await file.bytes.length;
    streamedRequest.sink.add(file.bytes);
    streamedRequest.sink.close();
    print('[UPLOADING] $fileName');
    var streamedResponse = await streamedRequest.send();
    Map<String, dynamic> jsonResponse = json.decode(
      String.fromCharCodes(await streamedResponse.stream.first),
    );
    if (!(jsonResponse['content_uri'] is String &&
        jsonResponse['content_uri'].isNotEmpty)) {
      throw ("Missing json key: 'content_uri' ${jsonResponse.toString()}");
    }
    return jsonResponse['content_uri'];
  }

  Future<dynamic> _syncRequest;

  Future<void> _sync() async {
    if (isLogged() == false) return;

    var action = '/client/r0/sync?filter=$syncFilters';

    if (prevBatch != null) {
      action += '&timeout=30000';
      action += '&since=${prevBatch}';
    }
    try {
      _syncRequest = jsonRequest(type: HTTPType.GET, action: action);
      final hash = _syncRequest.hashCode;
      final syncResp = await _syncRequest;
      if (hash != _syncRequest.hashCode) return;
      _timeoutFactor = 1;
      if (store != null) {
        await store.transaction(() {
          handleSync(syncResp);
          store.storePrevBatch(syncResp['next_batch']);
        });
      } else {
        await handleSync(syncResp);
      }
      if (prevBatch == null) {
        onFirstSync.add(true);
        prevBatch = syncResp['next_batch'];
        _sortRooms();
      }
      prevBatch = syncResp['next_batch'];
      await _updateUserDeviceKeys();
      if (hash == _syncRequest.hashCode) unawaited(_sync());
    } on MatrixException catch (exception) {
      onError.add(exception);
      await Future.delayed(Duration(seconds: syncErrorTimeoutSec), _sync);
    } catch (exception) {
      await Future.delayed(Duration(seconds: syncErrorTimeoutSec), _sync);
    }
  }

  /// Use this method only for testing utilities!
  void handleSync(dynamic sync) {
    if (sync['to_device'] is Map<String, dynamic> &&
        sync['to_device']['events'] is List<dynamic>) {
      _handleToDeviceEvents(sync['to_device']['events']);
    }
    if (sync['rooms'] is Map<String, dynamic>) {
      if (sync['rooms']['join'] is Map<String, dynamic>) {
        _handleRooms(sync['rooms']['join'], Membership.join);
      }
      if (sync['rooms']['invite'] is Map<String, dynamic>) {
        _handleRooms(sync['rooms']['invite'], Membership.invite);
      }
      if (sync['rooms']['leave'] is Map<String, dynamic>) {
        _handleRooms(sync['rooms']['leave'], Membership.leave);
      }
    }
    if (sync['presence'] is Map<String, dynamic> &&
        sync['presence']['events'] is List<dynamic>) {
      _handleGlobalEvents(sync['presence']['events'], 'presence');
    }
    if (sync['account_data'] is Map<String, dynamic> &&
        sync['account_data']['events'] is List<dynamic>) {
      _handleGlobalEvents(sync['account_data']['events'], 'account_data');
    }
    if (sync['device_lists'] is Map<String, dynamic>) {
      _handleDeviceListsEvents(sync['device_lists']);
    }
    if (sync['device_one_time_keys_count'] is Map<String, dynamic>) {
      _handleDeviceOneTimeKeysCount(sync['device_one_time_keys_count']);
    }
    while (_pendingToDeviceEvents.isNotEmpty) {
      _updateRoomsByToDeviceEvent(
        _pendingToDeviceEvents.removeLast(),
        addToPendingIfNotFound: false,
      );
    }
    onSync.add(sync);
  }

  void _handleDeviceOneTimeKeysCount(
      Map<String, dynamic> deviceOneTimeKeysCount) {
    if (!encryptionEnabled) return;
    // Check if there are at least half of max_number_of_one_time_keys left on the server
    // and generate and upload more if not.
    if (deviceOneTimeKeysCount['signed_curve25519'] is int) {
      final int oneTimeKeysCount = deviceOneTimeKeysCount['signed_curve25519'];
      if (oneTimeKeysCount < (_olmAccount.max_number_of_one_time_keys() / 2)) {
        // Generate and upload more one time keys:
        _uploadKeys();
      }
    }
  }

  void _handleDeviceListsEvents(Map<String, dynamic> deviceLists) {
    if (deviceLists['changed'] is List) {
      for (final userId in deviceLists['changed']) {
        if (_userDeviceKeys.containsKey(userId)) {
          _userDeviceKeys[userId].outdated = true;
        }
      }
      for (final userId in deviceLists['left']) {
        if (_userDeviceKeys.containsKey(userId)) {
          _userDeviceKeys.remove(userId);
        }
      }
    }
  }

  void _handleToDeviceEvents(List<dynamic> events) {
    for (var i = 0; i < events.length; i++) {
      var isValid = events[i] is Map &&
          events[i]['type'] is String &&
          events[i]['sender'] is String &&
          events[i]['content'] is Map;
      if (!isValid) {
        print('[Sync] Invalid To Device Event! ${events[i]}');
        continue;
      }
      var toDeviceEvent = ToDeviceEvent.fromJson(events[i]);
      if (toDeviceEvent.type == 'm.room.encrypted') {
        try {
          toDeviceEvent = decryptToDeviceEvent(toDeviceEvent);
        } catch (e) {
          print(
              '[LibOlm] Could not decrypt to device event from ${toDeviceEvent.sender}: ' +
                  e.toString());
          print(toDeviceEvent.sender);
          toDeviceEvent = ToDeviceEvent.fromJson(events[i]);
        }
      }
      _updateRoomsByToDeviceEvent(toDeviceEvent);
      onToDeviceEvent.add(toDeviceEvent);
    }
  }

  void _handleRooms(Map<String, dynamic> rooms, Membership membership) {
    rooms.forEach((String id, dynamic room) async {
      // calculate the notification counts, the limitedTimeline and prevbatch
      num highlight_count = 0;
      num notification_count = 0;
      var prev_batch = '';
      var limitedTimeline = false;

      if (room['unread_notifications'] is Map<String, dynamic>) {
        if (room['unread_notifications']['highlight_count'] is num) {
          highlight_count = room['unread_notifications']['highlight_count'];
        }
        if (room['unread_notifications']['notification_count'] is num) {
          notification_count =
              room['unread_notifications']['notification_count'];
        }
      }

      if (room['timeline'] is Map<String, dynamic>) {
        if (room['timeline']['limited'] is bool) {
          limitedTimeline = room['timeline']['limited'];
        }
        if (room['timeline']['prev_batch'] is String) {
          prev_batch = room['timeline']['prev_batch'];
        }
      }

      RoomSummary summary;

      if (room['summary'] is Map<String, dynamic>) {
        summary = RoomSummary.fromJson(room['summary']);
      }

      var update = RoomUpdate(
        id: id,
        membership: membership,
        notification_count: notification_count,
        highlight_count: highlight_count,
        limitedTimeline: limitedTimeline,
        prev_batch: prev_batch,
        summary: summary,
      );
      _updateRoomsByRoomUpdate(update);
      unawaited(store?.storeRoomUpdate(update));
      onRoomUpdate.add(update);

      /// Handle now all room events and save them in the database
      if (room['state'] is Map<String, dynamic> &&
          room['state']['events'] is List<dynamic>) {
        _handleRoomEvents(id, room['state']['events'], 'state');
      }

      if (room['invite_state'] is Map<String, dynamic> &&
          room['invite_state']['events'] is List<dynamic>) {
        _handleRoomEvents(id, room['invite_state']['events'], 'invite_state');
      }

      if (room['timeline'] is Map<String, dynamic> &&
          room['timeline']['events'] is List<dynamic>) {
        _handleRoomEvents(id, room['timeline']['events'], 'timeline');
      }

      if (room['ephemeral'] is Map<String, dynamic> &&
          room['ephemeral']['events'] is List<dynamic>) {
        _handleEphemerals(id, room['ephemeral']['events']);
      }

      if (room['account_data'] is Map<String, dynamic> &&
          room['account_data']['events'] is List<dynamic>) {
        _handleRoomEvents(id, room['account_data']['events'], 'account_data');
      }
    });
  }

  void _handleEphemerals(String id, List<dynamic> events) {
    for (num i = 0; i < events.length; i++) {
      _handleEvent(events[i], id, 'ephemeral');

      // Receipt events are deltas between two states. We will create a
      // fake room account data event for this and store the difference
      // there.
      if (events[i]['type'] == 'm.receipt') {
        var room = getRoomById(id);
        room ??= Room(id: id);

        var receiptStateContent =
            room.roomAccountData['m.receipt']?.content ?? {};
        for (var eventEntry in events[i]['content'].entries) {
          final String eventID = eventEntry.key;
          if (events[i]['content'][eventID]['m.read'] != null) {
            final Map<String, dynamic> userTimestampMap =
                events[i]['content'][eventID]['m.read'];
            for (var userTimestampMapEntry in userTimestampMap.entries) {
              final mxid = userTimestampMapEntry.key;

              // Remove previous receipt event from this user
              for (var entry in receiptStateContent.entries) {
                if (entry.value['m.read'] is Map<String, dynamic> &&
                    entry.value['m.read'].containsKey(mxid)) {
                  entry.value['m.read'].remove(mxid);
                  break;
                }
              }
              if (userTimestampMap[mxid] is Map<String, dynamic> &&
                  userTimestampMap[mxid].containsKey('ts')) {
                receiptStateContent[mxid] = {
                  'event_id': eventID,
                  'ts': userTimestampMap[mxid]['ts'],
                };
              }
            }
          }
        }
        events[i]['content'] = receiptStateContent;
        _handleEvent(events[i], id, 'account_data');
      }
    }
  }

  void _handleRoomEvents(String chat_id, List<dynamic> events, String type) {
    for (num i = 0; i < events.length; i++) {
      _handleEvent(events[i], chat_id, type);
    }
  }

  void _handleGlobalEvents(List<dynamic> events, String type) {
    for (var i = 0; i < events.length; i++) {
      if (events[i]['type'] is String &&
          events[i]['content'] is Map<String, dynamic>) {
        var update = UserUpdate(
          eventType: events[i]['type'],
          type: type,
          content: events[i],
        );
        store?.storeUserEventUpdate(update);
        onUserEvent.add(update);
      }
    }
  }

  void _handleEvent(Map<String, dynamic> event, String roomID, String type) {
    if (event['type'] is String && event['content'] is Map<String, dynamic>) {
      // The client must ignore any new m.room.encryption event to prevent
      // man-in-the-middle attacks!
      if (event['type'] == 'm.room.encryption' &&
          getRoomById(roomID).encrypted) {
        return;
      }

      var update = EventUpdate(
        eventType: event['type'],
        roomID: roomID,
        type: type,
        content: event,
      );
      if (event['type'] == 'm.room.encrypted') {
        update = update.decrypt(getRoomById(update.roomID));
      }
      store?.storeEventUpdate(update);
      _updateRoomsByEventUpdate(update);
      onEvent.add(update);

      if (event['type'] == 'm.call.invite') {
        onCallInvite.add(Event.fromJson(event, getRoomById(roomID)));
      } else if (event['type'] == 'm.call.hangup') {
        onCallHangup.add(Event.fromJson(event, getRoomById(roomID)));
      } else if (event['type'] == 'm.call.answer') {
        onCallAnswer.add(Event.fromJson(event, getRoomById(roomID)));
      } else if (event['type'] == 'm.call.candidates') {
        onCallCandidates.add(Event.fromJson(event, getRoomById(roomID)));
      }
    }
  }

  void _updateRoomsByRoomUpdate(RoomUpdate chatUpdate) {
    // Update the chat list item.
    // Search the room in the rooms
    num j = 0;
    for (j = 0; j < rooms.length; j++) {
      if (rooms[j].id == chatUpdate.id) break;
    }
    final found = (j < rooms.length && rooms[j].id == chatUpdate.id);
    final isLeftRoom = chatUpdate.membership == Membership.leave;

    // Does the chat already exist in the list rooms?
    if (!found && !isLeftRoom) {
      var position = chatUpdate.membership == Membership.invite ? 0 : j;
      // Add the new chat to the list
      var newRoom = Room(
        id: chatUpdate.id,
        membership: chatUpdate.membership,
        prev_batch: chatUpdate.prev_batch,
        highlightCount: chatUpdate.highlight_count,
        notificationCount: chatUpdate.notification_count,
        mHeroes: chatUpdate.summary?.mHeroes,
        mJoinedMemberCount: chatUpdate.summary?.mJoinedMemberCount,
        mInvitedMemberCount: chatUpdate.summary?.mInvitedMemberCount,
        roomAccountData: {},
        client: this,
      );
      newRoom.restoreGroupSessionKeys();
      rooms.insert(position, newRoom);
    }
    // If the membership is "leave" then remove the item and stop here
    else if (found && isLeftRoom) {
      rooms.removeAt(j);
    }
    // Update notification, highlight count and/or additional informations
    else if (found &&
        chatUpdate.membership != Membership.leave &&
        (rooms[j].membership != chatUpdate.membership ||
            rooms[j].notificationCount != chatUpdate.notification_count ||
            rooms[j].highlightCount != chatUpdate.highlight_count ||
            chatUpdate.summary != null)) {
      rooms[j].membership = chatUpdate.membership;
      rooms[j].notificationCount = chatUpdate.notification_count;
      rooms[j].highlightCount = chatUpdate.highlight_count;
      if (chatUpdate.prev_batch != null) {
        rooms[j].prev_batch = chatUpdate.prev_batch;
      }
      if (chatUpdate.summary != null) {
        if (chatUpdate.summary.mHeroes != null) {
          rooms[j].mHeroes = chatUpdate.summary.mHeroes;
        }
        if (chatUpdate.summary.mJoinedMemberCount != null) {
          rooms[j].mJoinedMemberCount = chatUpdate.summary.mJoinedMemberCount;
        }
        if (chatUpdate.summary.mInvitedMemberCount != null) {
          rooms[j].mInvitedMemberCount = chatUpdate.summary.mInvitedMemberCount;
        }
      }
      if (rooms[j].onUpdate != null) rooms[j].onUpdate.add(rooms[j].id);
    }
    _sortRooms();
  }

  void _updateRoomsByEventUpdate(EventUpdate eventUpdate) {
    if (eventUpdate.type == 'history') return;
    // Search the room in the rooms
    num j = 0;
    for (j = 0; j < rooms.length; j++) {
      if (rooms[j].id == eventUpdate.roomID) break;
    }
    final found = (j < rooms.length && rooms[j].id == eventUpdate.roomID);
    if (!found) return;
    if (eventUpdate.type == 'timeline' ||
        eventUpdate.type == 'state' ||
        eventUpdate.type == 'invite_state') {
      var stateEvent = Event.fromJson(eventUpdate.content, rooms[j]);
      if (stateEvent.type == EventTypes.Redaction) {
        final String redacts = eventUpdate.content['redacts'];
        rooms[j].states.states.forEach(
              (String key, Map<String, Event> states) => states.forEach(
                (String key, Event state) {
                  if (state.eventId == redacts) {
                    state.setRedactionEvent(stateEvent);
                  }
                },
              ),
            );
      } else {
        var prevState =
            rooms[j].getState(stateEvent.typeKey, stateEvent.stateKey);
        if (prevState != null &&
            prevState.time.millisecondsSinceEpoch >
                stateEvent.time.millisecondsSinceEpoch) return;
        rooms[j].setState(stateEvent);
      }
    } else if (eventUpdate.type == 'account_data') {
      rooms[j].roomAccountData[eventUpdate.eventType] =
          RoomAccountData.fromJson(eventUpdate.content, rooms[j]);
    } else if (eventUpdate.type == 'ephemeral') {
      rooms[j].ephemerals[eventUpdate.eventType] =
          RoomAccountData.fromJson(eventUpdate.content, rooms[j]);
    }
    if (rooms[j].onUpdate != null) rooms[j].onUpdate.add(rooms[j].id);
    if (eventUpdate.type == 'timeline') _sortRooms();
  }

  final List<ToDeviceEvent> _pendingToDeviceEvents = [];

  void _updateRoomsByToDeviceEvent(ToDeviceEvent toDeviceEvent,
      {addToPendingIfNotFound = true}) async {
    try {
      switch (toDeviceEvent.type) {
        case 'm.room_key':
        case 'm.forwarded_room_key':
          final roomId = toDeviceEvent.content['room_id'];
          var room = getRoomById(roomId);
          if (room == null && addToPendingIfNotFound) {
            _pendingToDeviceEvents.add(toDeviceEvent);
          }
          final String sessionId = toDeviceEvent.content['session_id'];
          if (toDeviceEvent.type == 'm.room_key' &&
              userDeviceKeys.containsKey(toDeviceEvent.sender) &&
              userDeviceKeys[toDeviceEvent.sender]
                  .deviceKeys
                  .containsKey(toDeviceEvent.content['requesting_device_id'])) {
            toDeviceEvent.content['sender_claimed_ed25519_key'] =
                userDeviceKeys[toDeviceEvent.sender]
                    .deviceKeys[toDeviceEvent.content['requesting_device_id']]
                    .ed25519Key;
          }
          room.setSessionKey(
            sessionId,
            toDeviceEvent.content,
            forwarded: toDeviceEvent.type == 'm.forwarded_room_key',
          );
          if (toDeviceEvent.type == 'm.forwarded_room_key') {
            await sendToDevice(
              [],
              'm.room_key_request',
              {
                'action': 'request_cancellation',
                'request_id': base64
                    .encode(utf8.encode(toDeviceEvent.content['room_id'])),
                'requesting_device_id': room.client.deviceID,
              },
              encrypted: false,
            );
          }
          break;
        case 'm.room_key_request':
          if (!toDeviceEvent.content.containsKey('body')) break;
          var room = getRoomById(toDeviceEvent.content['body']['room_id']);
          DeviceKeys deviceKeys;
          final String sessionId = toDeviceEvent.content['body']['session_id'];
          if (userDeviceKeys.containsKey(toDeviceEvent.sender) &&
              userDeviceKeys[toDeviceEvent.sender]
                  .deviceKeys
                  .containsKey(toDeviceEvent.content['requesting_device_id'])) {
            deviceKeys = userDeviceKeys[toDeviceEvent.sender]
                .deviceKeys[toDeviceEvent.content['requesting_device_id']];
            if (room.sessionKeys.containsKey(sessionId)) {
              final roomKeyRequest =
                  RoomKeyRequest.fromToDeviceEvent(toDeviceEvent, this);
              if (deviceKeys.userId == userID &&
                  deviceKeys.verified &&
                  !deviceKeys.blocked) {
                await roomKeyRequest.forwardKey();
              } else {
                onRoomKeyRequest.add(roomKeyRequest);
              }
            }
          }
          break;
      }
    } catch (e) {
      print('[Matrix] Error while processing to-device-event: ' + e.toString());
    }
  }

  bool _sortLock = false;

  /// The compare function how the rooms should be sorted internally. By default
  /// rooms are sorted by timestamp of the last m.room.message event or the last
  /// event if there is no known message.
  RoomSorter sortRoomsBy = (a, b) => b.timeCreated.millisecondsSinceEpoch
      .compareTo(a.timeCreated.millisecondsSinceEpoch);

  void _sortRooms() {
    if (prevBatch == null || _sortLock || rooms.length < 2) return;
    _sortLock = true;
    rooms?.sort(sortRoomsBy);
    _sortLock = false;
  }

  /// Gets an OpenID token object that the requester may supply to another service to verify their identity in Matrix.
  /// The generated token is only valid for exchanging for user information from the federation API for OpenID.
  Future<OpenIdCredentials> requestOpenIdCredentials() async {
    final response = await jsonRequest(
      type: HTTPType.POST,
      action: '/client/r0/user/$userID/openid/request_token',
      data: {},
    );
    return OpenIdCredentials.fromJson(response);
  }

  /// A map of known device keys per user.
  Map<String, DeviceKeysList> get userDeviceKeys => _userDeviceKeys;
  Map<String, DeviceKeysList> _userDeviceKeys = {};

  Future<Set<String>> _getUserIdsInEncryptedRooms() async {
    var userIds = <String>{};
    for (var i = 0; i < rooms.length; i++) {
      if (rooms[i].encrypted) {
        var userList = await rooms[i].requestParticipants();
        for (var user in userList) {
          if ([Membership.join, Membership.invite].contains(user.membership)) {
            userIds.add(user.id);
          }
        }
      }
    }
    return userIds;
  }

  Future<void> _updateUserDeviceKeys() async {
    try {
      if (!isLogged()) return;
      var trackedUserIds = await _getUserIdsInEncryptedRooms();
      trackedUserIds.add(userID);

      // Remove all userIds we no longer need to track the devices of.
      _userDeviceKeys
          .removeWhere((String userId, v) => !trackedUserIds.contains(userId));

      // Check if there are outdated device key lists. Add it to the set.
      var outdatedLists = <String, dynamic>{};
      for (var userId in trackedUserIds) {
        if (!userDeviceKeys.containsKey(userId)) {
          _userDeviceKeys[userId] = DeviceKeysList(userId);
        }
        var deviceKeysList = userDeviceKeys[userId];
        if (deviceKeysList.outdated) {
          outdatedLists[userId] = [];
        }
      }

      if (outdatedLists.isNotEmpty) {
        // Request the missing device key lists from the server.
        final response = await jsonRequest(
            type: HTTPType.POST,
            action: '/client/r0/keys/query',
            data: {'timeout': 10000, 'device_keys': outdatedLists});

        for (final rawDeviceKeyListEntry in response['device_keys'].entries) {
          final String userId = rawDeviceKeyListEntry.key;
          final oldKeys =
              Map<String, DeviceKeys>.from(_userDeviceKeys[userId].deviceKeys);
          _userDeviceKeys[userId].deviceKeys = {};
          for (final rawDeviceKeyEntry in rawDeviceKeyListEntry.value.entries) {
            final String deviceId = rawDeviceKeyEntry.key;

            // Set the new device key for this device
            if (!oldKeys.containsKey(deviceId)) {
              _userDeviceKeys[userId].deviceKeys[deviceId] =
                  DeviceKeys.fromJson(rawDeviceKeyEntry.value);
              if (deviceId == deviceID &&
                  _userDeviceKeys[userId].deviceKeys[deviceId].ed25519Key ==
                      fingerprintKey) {
                // Always trust the own device
                _userDeviceKeys[userId].deviceKeys[deviceId].verified = true;
              }
            } else {
              _userDeviceKeys[userId].deviceKeys[deviceId] = oldKeys[deviceId];
            }
          }
          _userDeviceKeys[userId].outdated = false;
        }
      }
      await storeAPI?.storeUserDeviceKeys(userDeviceKeys);
      rooms.forEach((Room room) {
        if (room.encrypted) {
          room.clearOutboundGroupSession();
        }
      });
    } catch (e) {
      print('[LibOlm] Unable to update user device keys: ' + e.toString());
    }
  }

  String get fingerprintKey => encryptionEnabled
      ? json.decode(_olmAccount.identity_keys())['ed25519']
      : null;
  String get identityKey => encryptionEnabled
      ? json.decode(_olmAccount.identity_keys())['curve25519']
      : null;

  /// Adds a signature to this json from this olm account.
  Map<String, dynamic> signJson(Map<String, dynamic> payload) {
    if (!encryptionEnabled) throw ('Encryption is disabled');
    final Map<String, dynamic> unsigned = payload['unsigned'];
    final Map<String, dynamic> signatures = payload['signatures'];
    payload.remove('unsigned');
    payload.remove('signatures');
    final canonical = canonicalJson.encode(payload);
    final signature = _olmAccount.sign(String.fromCharCodes(canonical));
    if (signatures != null) {
      payload['signatures'] = signatures;
    } else {
      payload['signatures'] = <String, dynamic>{};
    }
    payload['signatures'][userID] = <String, dynamic>{};
    payload['signatures'][userID]['ed25519:$deviceID'] = signature;
    if (unsigned != null) {
      payload['unsigned'] = unsigned;
    }
    return payload;
  }

  /// Checks the signature of a signed json object.
  bool checkJsonSignature(String key, Map<String, dynamic> signedJson,
      String userId, String deviceId) {
    if (!encryptionEnabled) throw ('Encryption is disabled');
    final Map<String, dynamic> signatures = signedJson['signatures'];
    if (signatures == null || !signatures.containsKey(userId)) return false;
    signedJson.remove('unsigned');
    signedJson.remove('signatures');
    if (!signatures[userId].containsKey('ed25519:$deviceId')) return false;
    final String signature = signatures[userId]['ed25519:$deviceId'];
    final canonical = canonicalJson.encode(signedJson);
    final message = String.fromCharCodes(canonical);
    var isValid = true;
    try {
      olm.Utility()
        ..ed25519_verify(key, message, signature)
        ..free();
    } catch (e) {
      isValid = false;
      print('[LibOlm] Signature check failed: ' + e.toString());
    }
    return isValid;
  }

  DateTime lastTimeKeysUploaded;

  /// Generates new one time keys, signs everything and upload it to the server.
  Future<bool> _uploadKeys({bool uploadDeviceKeys = false}) async {
    if (!encryptionEnabled) return true;

    final oneTimeKeysCount = _olmAccount.max_number_of_one_time_keys();
    _olmAccount.generate_one_time_keys(oneTimeKeysCount);
    final Map<String, dynamic> oneTimeKeys =
        json.decode(_olmAccount.one_time_keys());

    var signedOneTimeKeys = <String, dynamic>{};

    for (String key in oneTimeKeys['curve25519'].keys) {
      signedOneTimeKeys['signed_curve25519:$key'] = <String, dynamic>{};
      signedOneTimeKeys['signed_curve25519:$key']['key'] =
          oneTimeKeys['curve25519'][key];
      signedOneTimeKeys['signed_curve25519:$key'] =
          signJson(signedOneTimeKeys['signed_curve25519:$key']);
    }

    var keysContent = <String, dynamic>{
      if (uploadDeviceKeys)
        'device_keys': {
          'user_id': userID,
          'device_id': deviceID,
          'algorithms': [
            'm.olm.v1.curve25519-aes-sha2',
            'm.megolm.v1.aes-sha2'
          ],
          'keys': <String, dynamic>{},
        },
      'one_time_keys': signedOneTimeKeys,
    };
    if (uploadDeviceKeys) {
      final Map<String, dynamic> keys =
          json.decode(_olmAccount.identity_keys());
      for (var algorithm in keys.keys) {
        keysContent['device_keys']['keys']['$algorithm:$deviceID'] =
            keys[algorithm];
      }
      keysContent['device_keys'] =
          signJson(keysContent['device_keys'] as Map<String, dynamic>);
    }

    _olmAccount.mark_keys_as_published();
    final response = await jsonRequest(
      type: HTTPType.POST,
      action: '/client/r0/keys/upload',
      data: keysContent,
    );
    if (response['one_time_key_counts']['signed_curve25519'] !=
        oneTimeKeysCount) {
      return false;
    }
    await storeAPI?.storeClient();
    lastTimeKeysUploaded = DateTime.now();
    return true;
  }

  /// Try to decrypt a ToDeviceEvent encrypted with olm.
  ToDeviceEvent decryptToDeviceEvent(ToDeviceEvent toDeviceEvent) {
    if (toDeviceEvent.type != 'm.room.encrypted') {
      print(
          '[LibOlm] Warning! Tried to decrypt a not-encrypted to-device-event');
      return toDeviceEvent;
    }
    if (toDeviceEvent.content['algorithm'] != 'm.olm.v1.curve25519-aes-sha2') {
      throw ('Unknown algorithm: ${toDeviceEvent.content}');
    }
    if (!toDeviceEvent.content['ciphertext'].containsKey(identityKey)) {
      throw ("The message isn't sent for this device");
    }
    String plaintext;
    final String senderKey = toDeviceEvent.content['sender_key'];
    final String body =
        toDeviceEvent.content['ciphertext'][identityKey]['body'];
    final int type = toDeviceEvent.content['ciphertext'][identityKey]['type'];
    if (type != 0 && type != 1) {
      throw ('Unknown message type');
    }
    var existingSessions = olmSessions[senderKey];
    if (existingSessions != null) {
      for (var session in existingSessions) {
        if (type == 0 && session.matches_inbound(body) == true) {
          plaintext = session.decrypt(type, body);
          storeOlmSession(senderKey, session);
          break;
        } else if (type == 1) {
          try {
            plaintext = session.decrypt(type, body);
            storeOlmSession(senderKey, session);
            break;
          } catch (_) {
            plaintext = null;
          }
        }
      }
    }
    if (plaintext == null && type != 0) {
      throw ('No existing sessions found');
    }

    if (plaintext == null) {
      var newSession = olm.Session();
      newSession.create_inbound_from(_olmAccount, senderKey, body);
      _olmAccount.remove_one_time_keys(newSession);
      storeAPI?.storeClient();
      plaintext = newSession.decrypt(type, body);
      storeOlmSession(senderKey, newSession);
    }
    final Map<String, dynamic> plainContent = json.decode(plaintext);
    if (plainContent.containsKey('sender') &&
        plainContent['sender'] != toDeviceEvent.sender) {
      throw ("Message was decrypted but sender doesn't match");
    }
    if (plainContent.containsKey('recipient') &&
        plainContent['recipient'] != userID) {
      throw ("Message was decrypted but recipient doesn't match");
    }
    if (plainContent['recipient_keys'] is Map &&
        plainContent['recipient_keys']['ed25519'] is String &&
        plainContent['recipient_keys']['ed25519'] != fingerprintKey) {
      throw ("Message was decrypted but own fingerprint Key doesn't match");
    }
    return ToDeviceEvent(
      content: plainContent['content'],
      type: plainContent['type'],
      sender: toDeviceEvent.sender,
    );
  }

  /// A map from Curve25519 identity keys to existing olm sessions.
  Map<String, List<olm.Session>> get olmSessions => _olmSessions;
  final Map<String, List<olm.Session>> _olmSessions = {};

  void storeOlmSession(String curve25519IdentityKey, olm.Session session) {
    if (!_olmSessions.containsKey(curve25519IdentityKey)) {
      _olmSessions[curve25519IdentityKey] = [];
    }
    if (_olmSessions[curve25519IdentityKey]
            .indexWhere((s) => s.session_id() == session.session_id()) ==
        -1) {
      _olmSessions[curve25519IdentityKey].add(session);
    }
    var pickleMap = <String, List<String>>{};
    for (var entry in olmSessions.entries) {
      pickleMap[entry.key] = [];
      for (var session in entry.value) {
        try {
          pickleMap[entry.key].add(session.pickle(userID));
        } catch (e) {
          print('[LibOlm] Could not pickle olm session: ' + e.toString());
        }
      }
    }
    storeAPI?.setItem('/clients/$userID/olm-sessions', json.encode(pickleMap));
  }

  /// Sends an encrypted [message] of this [type] to these [deviceKeys]. To send
  /// the request to all devices of the current user, pass an empty list to [deviceKeys].
  Future<void> sendToDevice(
    List<DeviceKeys> deviceKeys,
    String type,
    Map<String, dynamic> message, {
    bool encrypted = true,
    List<User> toUsers,
  }) async {
    if (encrypted && !encryptionEnabled) return;
    // Don't send this message to blocked devices.
    if (deviceKeys.isNotEmpty) {
      deviceKeys.removeWhere((DeviceKeys deviceKeys) =>
          deviceKeys.blocked || deviceKeys.deviceId == deviceID);
      if (deviceKeys.isEmpty) return;
    }

    var sendToDeviceMessage = message;

    // Send with send-to-device messaging
    var data = <String, dynamic>{
      'messages': <String, dynamic>{},
    };
    if (deviceKeys.isEmpty) {
      if (toUsers == null) {
        data['messages'][userID] = <String, dynamic>{};
        data['messages'][userID]['*'] = sendToDeviceMessage;
      } else {
        for (var user in toUsers) {
          data['messages'][user.id] = <String, dynamic>{};
          data['messages'][user.id]['*'] = sendToDeviceMessage;
        }
      }
    } else {
      if (encrypted) {
        // Create new sessions with devices if there is no existing session yet.
        var deviceKeysWithoutSession = List<DeviceKeys>.from(deviceKeys);
        deviceKeysWithoutSession.removeWhere((DeviceKeys deviceKeys) =>
            olmSessions.containsKey(deviceKeys.curve25519Key));
        if (deviceKeysWithoutSession.isNotEmpty) {
          await startOutgoingOlmSessions(deviceKeysWithoutSession);
        }
      }
      for (var i = 0; i < deviceKeys.length; i++) {
        var device = deviceKeys[i];
        if (!data['messages'].containsKey(device.userId)) {
          data['messages'][device.userId] = <String, dynamic>{};
        }

        if (encrypted) {
          var existingSessions = olmSessions[device.curve25519Key];
          if (existingSessions == null || existingSessions.isEmpty) continue;
          existingSessions
              .sort((a, b) => a.session_id().compareTo(b.session_id()));

          final payload = {
            'type': type,
            'content': message,
            'sender': userID,
            'keys': {'ed25519': fingerprintKey},
            'recipient': device.userId,
            'recipient_keys': {'ed25519': device.ed25519Key},
          };
          final encryptResult =
              existingSessions.first.encrypt(json.encode(payload));
          storeOlmSession(device.curve25519Key, existingSessions.first);
          sendToDeviceMessage = {
            'algorithm': 'm.olm.v1.curve25519-aes-sha2',
            'sender_key': identityKey,
            'ciphertext': <String, dynamic>{},
          };
          sendToDeviceMessage['ciphertext'][device.curve25519Key] = {
            'type': encryptResult.type,
            'body': encryptResult.body,
          };
        }

        data['messages'][device.userId][device.deviceId] = sendToDeviceMessage;
      }
    }
    if (encrypted) type = 'm.room.encrypted';
    final messageID = 'msg${DateTime.now().millisecondsSinceEpoch}';
    await jsonRequest(
      type: HTTPType.PUT,
      action: '/client/r0/sendToDevice/$type/$messageID',
      data: data,
    );
  }

  Future<void> startOutgoingOlmSessions(List<DeviceKeys> deviceKeys,
      {bool checkSignature = true}) async {
    var requestingKeysFrom = <String, Map<String, String>>{};
    for (var device in deviceKeys) {
      if (requestingKeysFrom[device.userId] == null) {
        requestingKeysFrom[device.userId] = {};
      }
      requestingKeysFrom[device.userId][device.deviceId] = 'signed_curve25519';
    }

    final response = await jsonRequest(
      type: HTTPType.POST,
      action: '/client/r0/keys/claim',
      data: {'timeout': 10000, 'one_time_keys': requestingKeysFrom},
    );

    for (var userKeysEntry in response['one_time_keys'].entries) {
      final String userId = userKeysEntry.key;
      for (var deviceKeysEntry in userKeysEntry.value.entries) {
        final String deviceId = deviceKeysEntry.key;
        final fingerprintKey =
            userDeviceKeys[userId].deviceKeys[deviceId].ed25519Key;
        final identityKey =
            userDeviceKeys[userId].deviceKeys[deviceId].curve25519Key;
        for (Map<String, dynamic> deviceKey in deviceKeysEntry.value.values) {
          if (checkSignature &&
              checkJsonSignature(fingerprintKey, deviceKey, userId, deviceId) ==
                  false) {
            continue;
          }
          try {
            var session = olm.Session();
            session.create_outbound(_olmAccount, identityKey, deviceKey['key']);
            await storeOlmSession(identityKey, session);
          } catch (e) {
            print('[LibOlm] Could not create new outbound olm session: ' +
                e.toString());
          }
        }
      }
    }
  }

  /// Gets information about all devices for the current user.
  Future<List<UserDevice>> requestUserDevices() async {
    final response =
        await jsonRequest(type: HTTPType.GET, action: '/client/r0/devices');
    var userDevices = <UserDevice>[];
    for (final rawDevice in response['devices']) {
      userDevices.add(
        UserDevice.fromJson(rawDevice, this),
      );
    }
    return userDevices;
  }

  /// Gets information about all devices for the current user.
  Future<UserDevice> requestUserDevice(String deviceId) async {
    final response = await jsonRequest(
        type: HTTPType.GET, action: '/client/r0/devices/$deviceId');
    return UserDevice.fromJson(response, this);
  }

  /// Deletes the given devices, and invalidates any access token associated with them.
  Future<void> deleteDevices(List<String> deviceIds,
      {Map<String, dynamic> auth}) async {
    await jsonRequest(
      type: HTTPType.POST,
      action: '/client/r0/delete_devices',
      data: {
        'devices': deviceIds,
        if (auth != null) 'auth': auth,
      },
    );
    return;
  }

  /// Lists the public rooms on the server, with optional filter.
  Future<PublicRoomsResponse> requestPublicRooms({
    int limit,
    String since,
    String genericSearchTerm,
    String server,
    bool includeAllNetworks,
    String thirdPartyInstanceId,
  }) async {
    var action = '/client/r0/publicRooms';
    if (server != null) {
      action += '?server=$server';
    }
    final response = await jsonRequest(
      type: HTTPType.POST,
      action: action,
      data: {
        if (limit != null) 'limit': 10,
        if (since != null) 'since': since,
        if (genericSearchTerm != null)
          'filter': {'generic_search_term': genericSearchTerm},
        if (includeAllNetworks != null)
          'include_all_networks': includeAllNetworks,
        if (thirdPartyInstanceId != null)
          'third_party_instance_id': thirdPartyInstanceId,
      },
    );
    return PublicRoomsResponse.fromJson(response, this);
  }

  /// Whether all push notifications are muted using the [.m.rule.master]
  /// rule of the push rules: https://matrix.org/docs/spec/client_server/r0.6.0#m-rule-master
  bool get allPushNotificationsMuted {
    if (!accountData.containsKey('m.push_rules') ||
        !(accountData['m.push_rules'].content['global'] is Map)) {
      return false;
    }
    final Map<String, dynamic> globalPushRules =
        accountData['m.push_rules'].content['global'];
    if (globalPushRules == null) return false;

    if (globalPushRules['override'] is List) {
      for (var i = 0; i < globalPushRules['override'].length; i++) {
        if (globalPushRules['override'][i]['rule_id'] == '.m.rule.master') {
          return globalPushRules['override'][i]['enabled'];
        }
      }
    }
    return false;
  }

  Future<void> setMuteAllPushNotifications(bool muted) async {
    await jsonRequest(
      type: HTTPType.PUT,
      action: '/client/r0/pushrules/global/override/.m.rule.master/enabled',
      data: {'enabled': muted},
    );
    return;
  }
}
