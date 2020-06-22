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

import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/matrix_api.dart';
import 'package:famedlysdk/encryption.dart';
import 'package:famedlysdk/src/room.dart';
import 'package:famedlysdk/src/utils/device_keys_list.dart';
import 'package:famedlysdk/src/utils/matrix_file.dart';
import 'package:famedlysdk/src/utils/to_device_event.dart';
import 'package:http/http.dart' as http;
import 'package:pedantic/pedantic.dart';

import 'event.dart';
import 'room.dart';
import 'utils/event_update.dart';
import 'utils/room_update.dart';
import 'user.dart';
import 'database/database.dart' show Database;

typedef RoomSorter = int Function(Room a, Room b);

enum LoginState { logged, loggedOut }

/// Represents a Matrix client to communicate with a
/// [Matrix](https://matrix.org) homeserver and is the entry point for this
/// SDK.
class Client {
  int _id;
  int get id => _id;

  Database database;

  bool enableE2eeRecovery;

  MatrixApi api;

  Encryption encryption;

  /// Create a client
  /// clientName = unique identifier of this client
  /// debug: Print debug output?
  /// database: The database instance to use
  /// enableE2eeRecovery: Enable additional logic to try to recover from bad e2ee sessions
  Client(this.clientName,
      {this.debug = false,
      this.database,
      this.enableE2eeRecovery = false,
      http.Client httpClient}) {
    api = MatrixApi(debug: debug, httpClient: httpClient);
    onLoginStateChanged.stream.listen((loginState) {
      if (debug) {
        print('[LoginState]: ${loginState.toString()}');
      }
    });
  }

  /// Whether debug prints should be displayed.
  final bool debug;

  /// The required name for this client.
  final String clientName;

  /// The Matrix ID of the current logged user.
  String get userID => _userID;
  String _userID;

  /// This points to the position in the synchronization history.
  String prevBatch;

  /// The device ID is an unique identifier for this device.
  String get deviceID => _deviceID;
  String _deviceID;

  /// The device name is a human readable identifier for this device.
  String get deviceName => _deviceName;
  String _deviceName;

  /// Returns the current login state.
  bool isLogged() => api.accessToken != null;

  /// A list of all rooms the user is participating or invited.
  List<Room> get rooms => _rooms;
  List<Room> _rooms = [];

  /// Whether this client supports end-to-end encryption using olm.
  bool get encryptionEnabled => encryption != null && encryption.enabled;

  /// Whether this client is able to encrypt and decrypt files.
  bool get fileEncryptionEnabled => encryptionEnabled && true;

  String get identityKey => encryption?.identityKey ?? '';
  String get fingerprintKey => encryption?.fingerprintKey ?? '';

  /// Warning! This endpoint is for testing only!
  set rooms(List<Room> newList) {
    print('Warning! This endpoint is for testing only!');
    _rooms = newList;
  }

  /// Key/Value store of account data.
  Map<String, BasicEvent> accountData = {};

  /// Presences of users by a given matrix ID
  Map<String, Presence> presences = {};

  int _transactionCounter = 0;

  @Deprecated('Use [api.request()] instead')
  Future<Map<String, dynamic>> jsonRequest(
          {RequestType type,
          String action,
          dynamic data = '',
          int timeout,
          String contentType = 'application/json'}) =>
      api.request(
        type,
        action,
        data: data,
        timeout: timeout,
        contentType: contentType,
      );

  String generateUniqueTransactionId() {
    _transactionCounter++;
    return '${clientName}-${_transactionCounter}-${DateTime.now().millisecondsSinceEpoch}';
  }

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

  Map<String, dynamic> get directChats =>
      accountData['m.direct'] != null ? accountData['m.direct'].content : {};

  /// Returns the (first) room ID from the store which is a private chat with the user [userId].
  /// Returns null if there is none.
  String getDirectChatFromUserId(String userId) {
    if (accountData['m.direct'] != null &&
        accountData['m.direct'].content[userId] is List<dynamic> &&
        accountData['m.direct'].content[userId].length > 0) {
      for (final roomId in accountData['m.direct'].content[userId]) {
        final room = getRoomById(roomId);
        if (room != null && room.membership == Membership.join) {
          return roomId;
        }
      }
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

  /// Gets discovery information about the domain. The file may include additional keys.
  Future<WellKnownInformations> getWellKnownInformationsByUserId(
    String MatrixIdOrDomain,
  ) async {
    final response = await http
        .get('https://${MatrixIdOrDomain.domain}/.well-known/matrix/client');
    final rawJson = json.decode(response.body);
    return WellKnownInformations.fromJson(rawJson);
  }

  /// Checks the supported versions of the Matrix protocol and the supported
  /// login types. Returns false if the server is not compatible with the
  /// client.
  /// Throws FormatException, TimeoutException and MatrixException on error.
  Future<bool> checkServer(dynamic serverUrl) async {
    try {
      api.homeserver = (serverUrl is Uri) ? serverUrl : Uri.parse(serverUrl);
      final versions = await api.requestSupportedVersions();

      for (var i = 0; i < versions.versions.length; i++) {
        if (versions.versions[i] == 'r0.5.0' ||
            versions.versions[i] == 'r0.6.0') {
          break;
        } else if (i == versions.versions.length - 1) {
          return false;
        }
      }

      final loginTypes = await api.requestLoginTypes();
      if (loginTypes.flows.indexWhere((f) => f.type == 'm.login.password') ==
          -1) {
        return false;
      }

      return true;
    } catch (_) {
      api.homeserver = null;
      rethrow;
    }
  }

  /// Checks to see if a username is available, and valid, for the server.
  /// Returns the fully-qualified Matrix user ID (MXID) that has been registered.
  /// You have to call [checkServer] first to set a homeserver.
  Future<void> register({
    String kind,
    String username,
    String password,
    Map<String, dynamic> auth,
    String deviceId,
    String initialDeviceDisplayName,
    bool inhibitLogin,
  }) async {
    final response = await api.register(
      username: username,
      password: password,
      auth: auth,
      deviceId: deviceId,
      initialDeviceDisplayName: initialDeviceDisplayName,
      inhibitLogin: inhibitLogin,
    );

    // Connect if there is an access token in the response.
    if (response.accessToken == null ||
        response.deviceId == null ||
        response.userId == null) {
      throw 'Registered but token, device ID or user ID is null.';
    }
    await connect(
        newToken: response.accessToken,
        newUserID: response.userId,
        newHomeserver: api.homeserver,
        newDeviceName: initialDeviceDisplayName ?? '',
        newDeviceID: response.deviceId);
    return;
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

    final loginResp = await api.login(
      type: 'm.login.password',
      userIdentifierType: 'm.id.user',
      user: username,
      password: password,
      deviceId: deviceId,
      initialDeviceDisplayName: initialDeviceDisplayName,
    );

    // Connect if there is an access token in the response.
    if (loginResp.accessToken == null ||
        loginResp.deviceId == null ||
        loginResp.userId == null) {
      throw 'Registered but token, device ID or user ID is null.';
    }
    await connect(
      newToken: loginResp.accessToken,
      newUserID: loginResp.userId,
      newHomeserver: api.homeserver,
      newDeviceName: initialDeviceDisplayName ?? '',
      newDeviceID: loginResp.deviceId,
    );
    return true;
  }

  /// Sends a logout command to the homeserver and clears all local data,
  /// including all persistent data from the store.
  Future<void> logout() async {
    try {
      await api.logout();
    } catch (exception) {
      print(exception);
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

  final Map<String, Profile> _profileCache = {};

  /// Get the combined profile information for this user.
  /// If [getFromRooms] is true then the profile will first be searched from the
  /// room memberships. This is unstable if the given user makes use of different displaynames
  /// and avatars per room, which is common for some bots and bridges.
  /// If [cache] is true then
  /// the profile get cached for this session. Please note that then the profile may
  /// become outdated if the user changes the displayname or avatar in this session.
  Future<Profile> getProfileFromUserId(String userId,
      {bool cache = true, bool getFromRooms = true}) async {
    if (getFromRooms) {
      final room = rooms.firstWhere(
          (Room room) =>
              room
                  .getParticipants()
                  .indexWhere((User user) => user.id == userId) !=
              -1,
          orElse: () => null);
      if (room != null) {
        final user =
            room.getParticipants().firstWhere((User user) => user.id == userId);
        return Profile(user.displayName, user.avatarUrl);
      }
    }
    if (cache && _profileCache.containsKey(userId)) {
      return _profileCache[userId];
    }
    final profile = await api.requestProfile(userId);
    _profileCache[userId] = profile;
    return profile;
  }

  Future<List<Room>> get archive async {
    var archiveList = <Room>[];
    final sync = await api.sync(
      filter: '{"room":{"include_leave":true,"timeline":{"limit":10}}}',
      timeout: 0,
    );
    if (sync.rooms.leave is Map<String, dynamic>) {
      for (var entry in sync.rooms.leave.entries) {
        final id = entry.key;
        final room = entry.value;
        var leftRoom = Room(
            id: id,
            membership: Membership.leave,
            client: this,
            roomAccountData:
                room.accountData?.asMap()?.map((k, v) => MapEntry(v.type, v)) ??
                    <String, BasicRoomEvent>{},
            mHeroes: []);
        if (room.timeline?.events != null) {
          for (var event in room.timeline.events) {
            leftRoom.setState(Event.fromMatrixEvent(event, leftRoom));
          }
        }
        if (room.state != null) {
          for (var event in room.state) {
            leftRoom.setState(Event.fromMatrixEvent(event, leftRoom));
          }
        }
        archiveList.add(leftRoom);
      }
    }
    return archiveList;
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

  /// Changes the user's displayname.
  Future<void> setDisplayname(String displayname) =>
      api.setDisplayname(userID, displayname);

  /// Uploads a new user avatar for this user.
  Future<void> setAvatar(MatrixFile file) async {
    final uploadResp = await api.upload(file.bytes, file.path);
    await api.setAvatarUrl(userID, Uri.parse(uploadResp));
    return;
  }

  /// Returns the push rules for the logged in user.
  PushRuleSet get pushRules => accountData.containsKey('m.push_rules')
      ? PushRuleSet.fromJson(accountData['m.push_rules'].content)
      : null;

  static String syncFilters = '{"room":{"state":{"lazy_load_members":true}}}';
  static String messagesFilters = '{"lazy_load_members":true}';
  static const List<String> supportedDirectEncryptionAlgorithms = [
    'm.olm.v1.curve25519-aes-sha2'
  ];
  static const List<String> supportedGroupEncryptionAlgorithms = [
    'm.megolm.v1.aes-sha2'
  ];
  static const int defaultThumbnailSize = 256;

  /// The newEvent signal is the most important signal in this concept. Every time
  /// the app receives a new synchronization, this event is called for every signal
  /// to update the GUI. For example, for a new message, it is called:
  /// onRoomEvent( "m.room.message", "!chat_id:server.com", "timeline", {sender: "@bob:server.com", body: "Hello world"} )
  final StreamController<EventUpdate> onEvent = StreamController.broadcast();

  /// Outside of the events there are updates for the global chat states which
  /// are handled by this signal:
  final StreamController<RoomUpdate> onRoomUpdate =
      StreamController.broadcast();

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

  /// Synchronization erros are coming here.
  final StreamController<SyncError> onSyncError = StreamController.broadcast();

  /// Synchronization erros are coming here.
  final StreamController<ToDeviceEventDecryptionError> onOlmError =
      StreamController.broadcast();

  /// This is called once, when the first sync has received.
  final StreamController<bool> onFirstSync = StreamController.broadcast();

  /// When a new sync response is coming in, this gives the complete payload.
  final StreamController<SyncUpdate> onSync = StreamController.broadcast();

  /// Callback will be called on presences.
  final StreamController<Presence> onPresence = StreamController.broadcast();

  /// Callback will be called on account data updates.
  final StreamController<BasicEvent> onAccountData =
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

  /// Will be called when another device is requesting verification with this device.
  final StreamController<KeyVerification> onKeyVerificationRequest =
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
  ///          .jsonRequest(type: RequestType.POST, action: "/client/r0/login", data: {
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
    Uri newHomeserver,
    String newUserID,
    String newDeviceName,
    String newDeviceID,
    String newPrevBatch,
    String newOlmAccount,
  }) async {
    String olmAccount;
    if (database != null) {
      final account = await database.getClient(clientName);
      if (account != null) {
        _id = account.clientId;
        api.homeserver = Uri.parse(account.homeserverUrl);
        api.accessToken = account.token;
        _userID = account.userId;
        _deviceID = account.deviceId;
        _deviceName = account.deviceName;
        prevBatch = account.prevBatch;
        olmAccount = account.olmAccount;
      }
    }
    api.accessToken = newToken ?? api.accessToken;
    api.homeserver = newHomeserver ?? api.homeserver;
    _userID = newUserID ?? _userID;
    _deviceID = newDeviceID ?? _deviceID;
    _deviceName = newDeviceName ?? _deviceName;
    prevBatch = newPrevBatch ?? prevBatch;
    olmAccount = newOlmAccount ?? olmAccount;

    if (api.accessToken == null || api.homeserver == null || _userID == null) {
      // we aren't logged in
      encryption?.dispose();
      encryption = null;
      onLoginStateChanged.add(LoginState.loggedOut);
      return;
    }

    encryption = Encryption(
        debug: debug, client: this, enableE2eeRecovery: enableE2eeRecovery);
    await encryption.init(olmAccount);

    if (database != null) {
      if (id != null) {
        await database.updateClient(
          api.homeserver.toString(),
          api.accessToken,
          _userID,
          _deviceID,
          _deviceName,
          prevBatch,
          encryption?.pickledOlmAccount,
          id,
        );
      } else {
        _id = await database.insertClient(
          clientName,
          api.homeserver.toString(),
          api.accessToken,
          _userID,
          _deviceID,
          _deviceName,
          prevBatch,
          encryption?.pickledOlmAccount,
        );
      }
      _userDeviceKeys = await database.getUserDeviceKeys(id);
      _rooms = await database.getRoomList(this, onlyLeft: false);
      _sortRooms();
      accountData = await database.getAccountData(id);
      presences = await database.getPresences(id);
    }

    onLoginStateChanged.add(LoginState.logged);

    return _sync();
  }

  /// Used for testing only
  void setUserId(String s) {
    _userID = s;
  }

  /// Resets all settings and stops the synchronisation.
  void clear() {
    database?.clear(id);
    _id = api.accessToken =
        api.homeserver = _userID = _deviceID = _deviceName = prevBatch = null;
    _rooms = [];
    encryption?.dispose();
    encryption = null;
    onLoginStateChanged.add(LoginState.loggedOut);
  }

  Future<SyncUpdate> _syncRequest;

  Future<void> _sync() async {
    if (isLogged() == false || _disposed) return;
    try {
      _syncRequest = api.sync(
        filter: syncFilters,
        since: prevBatch,
        timeout: prevBatch != null ? 30000 : null,
      );
      if (_disposed) return;
      final hash = _syncRequest.hashCode;
      final syncResp = await _syncRequest;
      if (hash != _syncRequest.hashCode) return;
      if (database != null) {
        await database.transaction(() async {
          await handleSync(syncResp);
          if (prevBatch != syncResp.nextBatch) {
            await database.storePrevBatch(syncResp.nextBatch, id);
          }
        });
      } else {
        await handleSync(syncResp);
      }
      if (_disposed) return;
      if (prevBatch == null) {
        onFirstSync.add(true);
        prevBatch = syncResp.nextBatch;
        _sortRooms();
      }
      prevBatch = syncResp.nextBatch;
      await _updateUserDeviceKeys();
      if (encryptionEnabled) {
        encryption.onSync();
      }
      if (hash == _syncRequest.hashCode) unawaited(_sync());
    } on MatrixException catch (exception) {
      onError.add(exception);
      await Future.delayed(Duration(seconds: syncErrorTimeoutSec), _sync);
    } catch (e, s) {
      print('Error during processing events: ' + e.toString());
      print(s);
      onSyncError.add(SyncError(
          exception: e is Exception ? e : Exception(e), stackTrace: s));
      await Future.delayed(Duration(seconds: syncErrorTimeoutSec), _sync);
    }
  }

  /// Use this method only for testing utilities!
  Future<void> handleSync(SyncUpdate sync) async {
    if (sync.toDevice != null) {
      await _handleToDeviceEvents(sync.toDevice);
    }
    if (sync.rooms != null) {
      if (sync.rooms.join != null) {
        await _handleRooms(sync.rooms.join, Membership.join);
      }
      if (sync.rooms.invite != null) {
        await _handleRooms(sync.rooms.invite, Membership.invite);
      }
      if (sync.rooms.leave != null) {
        await _handleRooms(sync.rooms.leave, Membership.leave);
      }
    }
    if (sync.presence != null) {
      for (final newPresence in sync.presence) {
        if (database != null) {
          await database.storeUserEventUpdate(
            id,
            'presence',
            newPresence.type,
            newPresence.toJson(),
          );
        }
        presences[newPresence.senderId] = newPresence;
        onPresence.add(newPresence);
      }
    }
    if (sync.accountData != null) {
      for (final newAccountData in sync.accountData) {
        if (database != null) {
          await database.storeUserEventUpdate(
            id,
            'account_data',
            newAccountData.type,
            newAccountData.toJson(),
          );
        }
        accountData[newAccountData.type] = newAccountData;
        if (onAccountData != null) onAccountData.add(newAccountData);
      }
    }
    if (sync.deviceLists != null) {
      await _handleDeviceListsEvents(sync.deviceLists);
    }
    if (sync.deviceOneTimeKeysCount != null && encryptionEnabled) {
      encryption.handleDeviceOneTimeKeysCount(sync.deviceOneTimeKeysCount);
    }
    onSync.add(sync);
  }

  Future<void> _handleDeviceListsEvents(DeviceListsUpdate deviceLists) async {
    if (deviceLists.changed is List) {
      for (final userId in deviceLists.changed) {
        if (_userDeviceKeys.containsKey(userId)) {
          _userDeviceKeys[userId].outdated = true;
          if (database != null) {
            await database.storeUserDeviceKeysInfo(id, userId, true);
          }
        }
      }
      for (final userId in deviceLists.left) {
        if (_userDeviceKeys.containsKey(userId)) {
          _userDeviceKeys.remove(userId);
        }
      }
    }
  }

  Future<void> _handleToDeviceEvents(List<BasicEventWithSender> events) async {
    for (var i = 0; i < events.length; i++) {
      var toDeviceEvent = ToDeviceEvent.fromJson(events[i].toJson());
      if (toDeviceEvent.type == EventTypes.Encrypted && encryptionEnabled) {
        try {
          toDeviceEvent = await encryption.decryptToDeviceEvent(toDeviceEvent);
        } catch (e, s) {
          print(
              '[LibOlm] Could not decrypt to device event from ${toDeviceEvent.sender} with content: ${toDeviceEvent.content}');
          print(e);
          print(s);
          onOlmError.add(
            ToDeviceEventDecryptionError(
              exception: e is Exception ? e : Exception(e),
              stackTrace: s,
              toDeviceEvent: toDeviceEvent,
            ),
          );
          toDeviceEvent = ToDeviceEvent.fromJson(events[i].toJson());
        }
      }
      if (encryptionEnabled) {
        await encryption.handleToDeviceEvent(toDeviceEvent);
      }
      onToDeviceEvent.add(toDeviceEvent);
    }
  }

  Future<void> _handleRooms(
      Map<String, SyncRoomUpdate> rooms, Membership membership) async {
    for (final entry in rooms.entries) {
      final id = entry.key;
      final room = entry.value;

      var update = RoomUpdate.fromSyncRoomUpdate(room, id);
      if (database != null) {
        await database.storeRoomUpdate(this.id, update, getRoomById(id));
      }
      _updateRoomsByRoomUpdate(update);
      final roomObj = getRoomById(id);
      if (update.limitedTimeline && roomObj != null) {
        roomObj.resetSortOrder();
      }
      onRoomUpdate.add(update);

      var handledEvents = false;

      /// Handle now all room events and save them in the database
      if (room is JoinedRoomUpdate) {
        if (room.state?.isNotEmpty ?? false) {
          await _handleRoomEvents(
              id, room.state.map((i) => i.toJson()).toList(), 'state');
          handledEvents = true;
        }
        if (room.timeline?.events?.isNotEmpty ?? false) {
          await _handleRoomEvents(id,
              room.timeline.events.map((i) => i.toJson()).toList(), 'timeline');
          handledEvents = true;
        }
        if (room.ephemeral?.isNotEmpty ?? false) {
          await _handleEphemerals(
              id, room.ephemeral.map((i) => i.toJson()).toList());
        }
        if (room.accountData?.isNotEmpty ?? false) {
          await _handleRoomEvents(id,
              room.accountData.map((i) => i.toJson()).toList(), 'account_data');
        }
      }
      if (room is LeftRoomUpdate) {
        if (room.timeline?.events?.isNotEmpty ?? false) {
          await _handleRoomEvents(id,
              room.timeline.events.map((i) => i.toJson()).toList(), 'timeline');
          handledEvents = true;
        }
        if (room.accountData?.isNotEmpty ?? false) {
          await _handleRoomEvents(id,
              room.accountData.map((i) => i.toJson()).toList(), 'account_data');
        }
        if (room.state?.isNotEmpty ?? false) {
          await _handleRoomEvents(
              id, room.state.map((i) => i.toJson()).toList(), 'state');
          handledEvents = true;
        }
      }
      if (room is InvitedRoomUpdate &&
          (room.inviteState?.isNotEmpty ?? false)) {
        await _handleRoomEvents(id,
            room.inviteState.map((i) => i.toJson()).toList(), 'invite_state');
      }
      if (handledEvents && database != null && roomObj != null) {
        await roomObj.updateSortOrder();
      }
    }
  }

  Future<void> _handleEphemerals(String id, List<dynamic> events) async {
    for (num i = 0; i < events.length; i++) {
      await _handleEvent(events[i], id, 'ephemeral');

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
              if (receiptStateContent[eventID] is Map<String, dynamic> &&
                  receiptStateContent[eventID]['m.read']
                      is Map<String, dynamic> &&
                  receiptStateContent[eventID]['m.read'].containsKey(mxid)) {
                receiptStateContent[eventID]['m.read'].remove(mxid);
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
        await _handleEvent(events[i], id, 'account_data');
      }
    }
  }

  Future<void> _handleRoomEvents(
      String chat_id, List<dynamic> events, String type) async {
    for (num i = 0; i < events.length; i++) {
      await _handleEvent(events[i], chat_id, type);
    }
  }

  Future<void> _handleEvent(
      Map<String, dynamic> event, String roomID, String type) async {
    if (event['type'] is String && event['content'] is Map<String, dynamic>) {
      // The client must ignore any new m.room.encryption event to prevent
      // man-in-the-middle attacks!
      final room = getRoomById(roomID);
      if (room == null ||
          (event['type'] == EventTypes.Encryption &&
              room.encrypted &&
              event['content']['algorithm'] !=
                  room.getState(EventTypes.Encryption)?.content['algorithm'])) {
        return;
      }

      // ephemeral events aren't persisted and don't need a sort order - they are
      // expected to be processed as soon as they come in
      final sortOrder = type != 'ephemeral' ? room.newSortOrder : 0.0;
      var update = EventUpdate(
        eventType: event['type'],
        roomID: roomID,
        type: type,
        content: event,
        sortOrder: sortOrder,
      );
      if (event['type'] == EventTypes.Encrypted && encryptionEnabled) {
        update = await update.decrypt(room);
      }
      if (type != 'ephemeral' && database != null) {
        await database.storeEventUpdate(id, update);
      }
      _updateRoomsByEventUpdate(update);
      onEvent.add(update);

      if (event['type'] == 'm.call.invite') {
        onCallInvite.add(Event.fromJson(event, room, sortOrder));
      } else if (event['type'] == 'm.call.hangup') {
        onCallHangup.add(Event.fromJson(event, room, sortOrder));
      } else if (event['type'] == 'm.call.answer') {
        onCallAnswer.add(Event.fromJson(event, room, sortOrder));
      } else if (event['type'] == 'm.call.candidates') {
        onCallCandidates.add(Event.fromJson(event, room, sortOrder));
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
      var stateEvent =
          Event.fromJson(eventUpdate.content, rooms[j], eventUpdate.sortOrder);
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
        var prevState = rooms[j].getState(stateEvent.type, stateEvent.stateKey);
        if (prevState != null &&
            prevState.originServerTs.millisecondsSinceEpoch >
                stateEvent.originServerTs.millisecondsSinceEpoch) return;
        rooms[j].setState(stateEvent);
      }
    } else if (eventUpdate.type == 'account_data') {
      rooms[j].roomAccountData[eventUpdate.eventType] =
          BasicRoomEvent.fromJson(eventUpdate.content);
    } else if (eventUpdate.type == 'ephemeral') {
      rooms[j].ephemerals[eventUpdate.eventType] =
          BasicRoomEvent.fromJson(eventUpdate.content);
    }
    if (rooms[j].onUpdate != null) rooms[j].onUpdate.add(rooms[j].id);
    if (eventUpdate.type == 'timeline') _sortRooms();
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
      final dbActions = <Future<dynamic> Function()>[];
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
        final response =
            await api.requestDeviceKeys(outdatedLists, timeout: 10000);

        for (final rawDeviceKeyListEntry in response.deviceKeys.entries) {
          final userId = rawDeviceKeyListEntry.key;
          if (!userDeviceKeys.containsKey(userId)) {
            _userDeviceKeys[userId] = DeviceKeysList(userId);
          }
          final oldKeys =
              Map<String, DeviceKeys>.from(_userDeviceKeys[userId].deviceKeys);
          _userDeviceKeys[userId].deviceKeys = {};
          for (final rawDeviceKeyEntry in rawDeviceKeyListEntry.value.entries) {
            final deviceId = rawDeviceKeyEntry.key;

            // Set the new device key for this device

            if (!oldKeys.containsKey(deviceId)) {
              final entry =
                  DeviceKeys.fromMatrixDeviceKeys(rawDeviceKeyEntry.value);
              if (entry.isValid) {
                _userDeviceKeys[userId].deviceKeys[deviceId] = entry;
                if (deviceId == deviceID &&
                    entry.ed25519Key == encryption?.fingerprintKey) {
                  // Always trust the own device
                  entry.verified = true;
                }
              }
              if (database != null) {
                dbActions.add(() => database.storeUserDeviceKey(
                      id,
                      userId,
                      deviceId,
                      json.encode(_userDeviceKeys[userId]
                          .deviceKeys[deviceId]
                          .toJson()),
                      _userDeviceKeys[userId].deviceKeys[deviceId].verified,
                      _userDeviceKeys[userId].deviceKeys[deviceId].blocked,
                    ));
              }
            } else {
              _userDeviceKeys[userId].deviceKeys[deviceId] = oldKeys[deviceId];
            }
          }
          if (database != null) {
            for (final oldDeviceKeyEntry in oldKeys.entries) {
              final deviceId = oldDeviceKeyEntry.key;
              if (!_userDeviceKeys[userId].deviceKeys.containsKey(deviceId)) {
                // we need to remove an old key
                dbActions.add(
                    () => database.removeUserDeviceKey(id, userId, deviceId));
              }
            }
          }
          _userDeviceKeys[userId].outdated = false;
          if (database != null) {
            dbActions
                .add(() => database.storeUserDeviceKeysInfo(id, userId, false));
          }
        }
      }
      await database?.transaction(() async {
        for (final f in dbActions) {
          await f();
        }
      });
    } catch (e) {
      print('[LibOlm] Unable to update user device keys: ' + e.toString());
    }
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
    var data = <String, Map<String, Map<String, dynamic>>>{};
    if (deviceKeys.isEmpty) {
      if (toUsers == null) {
        data[userID] = {};
        data[userID]['*'] = sendToDeviceMessage;
      } else {
        for (var user in toUsers) {
          data[user.id] = {};
          data[user.id]['*'] = sendToDeviceMessage;
        }
      }
    } else {
      if (encrypted) {
        data =
            await encryption.encryptToDeviceMessage(deviceKeys, type, message);
      } else {
        for (final device in deviceKeys) {
          if (!data.containsKey(device.userId)) {
            data[device.userId] = {};
          }
          data[device.userId][device.deviceId] = sendToDeviceMessage;
        }
      }
    }
    if (encrypted) type = EventTypes.Encrypted;
    final messageID = generateUniqueTransactionId();
    await api.sendToDevice(type, messageID, data);
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
    await api.enablePushRule(
      'global',
      PushRuleKind.override,
      '.m.rule.master',
      muted,
    );
    return;
  }

  /// Changes the password. You should either set oldPasswort or another authentication flow.
  Future<void> changePassword(String newPassword,
      {String oldPassword, Map<String, dynamic> auth}) async {
    try {
      if (oldPassword != null) {
        auth = {
          'type': 'm.login.password',
          'user': userID,
          'password': oldPassword,
        };
      }
      await api.changePassword(newPassword, auth: auth);
    } on MatrixException catch (matrixException) {
      if (!matrixException.requireAdditionalAuthentication) {
        rethrow;
      }
      if (matrixException.authenticationFlows.length != 1 ||
          !matrixException.authenticationFlows.first.stages
              .contains('m.login.password')) {
        rethrow;
      }
      if (oldPassword == null) {
        rethrow;
      }
      return changePassword(
        newPassword,
        auth: {
          'type': 'm.login.password',
          'user': userID,
          'identifier': {'type': 'm.id.user', 'user': userID},
          'password': oldPassword,
          'session': matrixException.session,
        },
      );
    } catch (_) {
      rethrow;
    }
  }

  bool _disposed = false;

  /// Stops the synchronization and closes the database. After this
  /// you can safely make this Client instance null.
  Future<void> dispose({bool closeDatabase = false}) async {
    _disposed = true;
    if (closeDatabase) await database?.close();
    database = null;
    return;
  }
}

class SyncError {
  Exception exception;
  StackTrace stackTrace;
  SyncError({this.exception, this.stackTrace});
}
