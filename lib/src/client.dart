/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020, 2021 Famedly GmbH
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
import 'dart:typed_data';

import 'package:famedlysdk/src/utils/run_in_root.dart';
import 'package:http/http.dart' as http;
import 'package:olm/olm.dart' as olm;
import 'package:pedantic/pedantic.dart';

import '../encryption.dart';
import '../famedlysdk.dart';
import 'database/database.dart' show Database;
import 'event.dart';
import 'room.dart';
import 'user.dart';
import 'utils/commands_extension.dart';
import 'utils/device_keys_list.dart';
import 'utils/event_update.dart';
import 'utils/matrix_file.dart';
import 'utils/room_update.dart';
import 'utils/to_device_event.dart';
import 'utils/uia_request.dart';

typedef RoomSorter = int Function(Room a, Room b);

enum LoginState { logged, loggedOut }

/// Represents a Matrix client to communicate with a
/// [Matrix](https://matrix.org) homeserver and is the entry point for this
/// SDK.
class Client extends MatrixApi {
  int _id;

  // Keeps track of the currently ongoing syncRequest
  // in case we want to cancel it.
  int _currentSyncId;

  int get id => _id;

  final FutureOr<Database> Function(Client) databaseBuilder;
  Database _database;

  Database get database => _database;

  bool enableE2eeRecovery;

  @deprecated
  MatrixApi get api => this;

  Encryption encryption;

  Set<KeyVerificationMethod> verificationMethods;

  Set<String> importantStateEvents;

  Set<String> roomPreviewLastEvents;

  Set<String> supportedLoginTypes;

  int sendMessageTimeoutSeconds;

  bool requestHistoryOnLimitedTimeline;

  bool formatLocalpart = true;

  bool mxidLocalPartFallback = true;

  // For CommandsClientExtension
  final Map<String, FutureOr<String> Function(CommandArgs)> commands = {};
  final Filter syncFilter;

  String syncFilterId;

  /// Create a client
  /// [clientName] = unique identifier of this client
  /// [database]: The database instance to use
  /// [enableE2eeRecovery]: Enable additional logic to try to recover from bad e2ee sessions
  /// [verificationMethods]: A set of all the verification methods this client can handle. Includes:
  ///    KeyVerificationMethod.numbers: Compare numbers. Most basic, should be supported
  ///    KeyVerificationMethod.emoji: Compare emojis
  /// [importantStateEvents]: A set of all the important state events to load when the client connects.
  ///    To speed up performance only a set of state events is loaded on startup, those that are
  ///    needed to display a room list. All the remaining state events are automatically post-loaded
  ///    when opening the timeline of a room or manually by calling `room.postLoad()`.
  ///    This set will always include the following state events:
  ///     - m.room.name
  ///     - m.room.avatar
  ///     - m.room.message
  ///     - m.room.encrypted
  ///     - m.room.encryption
  ///     - m.room.canonical_alias
  ///     - m.room.tombstone
  ///     - *some* m.room.member events, where needed
  /// [roomPreviewLastEvents]: The event types that should be used to calculate the last event
  ///     in a room for the room list.
  /// Set [requestHistoryOnLimitedTimeline] to controll the automatic behaviour if the client
  /// receives a limited timeline flag for a room.
  /// If [mxidLocalPartFallback] is true, then the local part of the mxid will be shown
  /// if there is no other displayname available. If not then this will return "Unknown user".
  /// If [formatLocalpart] is true, then the localpart of an mxid will
  /// be formatted in the way, that all "_" characters are becomming white spaces and
  /// the first character of each word becomes uppercase.
  /// If your client supports more login types like login with token or SSO, then add this to
  /// [supportedLoginTypes]. Set a custom [syncFilter] if you like. By default the app
  /// will use lazy_load_members.
  Client(
    this.clientName, {
    this.databaseBuilder,
    this.enableE2eeRecovery = false,
    this.verificationMethods,
    http.Client httpClient,
    this.importantStateEvents,
    this.roomPreviewLastEvents,
    this.pinUnreadRooms = false,
    this.sendMessageTimeoutSeconds = 60,
    this.requestHistoryOnLimitedTimeline = false,
    this.supportedLoginTypes,
    Filter syncFilter,
    @deprecated bool debug,
  }) : syncFilter = syncFilter ??
            Filter(
              room: RoomFilter(
                state: StateFilter(lazyLoadMembers: true),
              ),
            ) {
    supportedLoginTypes ??= {AuthenticationTypes.password};
    verificationMethods ??= <KeyVerificationMethod>{};
    importantStateEvents ??= {};
    importantStateEvents.addAll([
      EventTypes.RoomName,
      EventTypes.RoomAvatar,
      EventTypes.Message,
      EventTypes.Encrypted,
      EventTypes.Encryption,
      EventTypes.RoomCanonicalAlias,
      EventTypes.RoomTombstone,
    ]);
    roomPreviewLastEvents ??= {};
    roomPreviewLastEvents.addAll([
      EventTypes.Message,
      EventTypes.Encrypted,
      EventTypes.Sticker,
    ]);
    this.httpClient = httpClient ?? http.Client();

    // register all the default commands
    registerDefaultCommands();
  }

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
  bool isLogged() => accessToken != null;

  /// A list of all rooms the user is participating or invited.
  List<Room> get rooms => _rooms;
  List<Room> _rooms = [];

  /// Whether this client supports end-to-end encryption using olm.
  bool get encryptionEnabled => encryption != null && encryption.enabled;

  /// Whether this client is able to encrypt and decrypt files.
  bool get fileEncryptionEnabled => encryptionEnabled && true;

  String get identityKey => encryption?.identityKey ?? '';

  String get fingerprintKey => encryption?.fingerprintKey ?? '';

  /// Wheather this session is unknown to others
  bool get isUnknownSession =>
      !userDeviceKeys.containsKey(userID) ||
      !userDeviceKeys[userID].deviceKeys.containsKey(deviceID) ||
      !userDeviceKeys[userID].deviceKeys[deviceID].signed;

  /// Warning! This endpoint is for testing only!
  set rooms(List<Room> newList) {
    Logs().w('Warning! This endpoint is for testing only!');
    _rooms = newList;
  }

  /// Key/Value store of account data.
  Map<String, BasicEvent> accountData = {};

  /// Presences of users by a given matrix ID
  Map<String, Presence> presences = {};

  int _transactionCounter = 0;

  String generateUniqueTransactionId() {
    _transactionCounter++;
    return '$clientName-$_transactionCounter-${DateTime.now().millisecondsSinceEpoch}';
  }

  Room getRoomByAlias(String alias) {
    for (final room in rooms) {
      if (room.canonicalAlias == alias) return room;
    }
    return null;
  }

  Room getRoomById(String id) {
    for (final room in rooms) {
      if (room.id == id) return room;
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
      final potentialRooms = <Room>{};
      for (final roomId in accountData['m.direct'].content[userId]) {
        final room = getRoomById(roomId);
        if (room != null && room.membership == Membership.join) {
          potentialRooms.add(room);
        }
      }
      if (potentialRooms.isNotEmpty) {
        return potentialRooms
            .fold(
                null,
                (prev, r) => prev == null
                    ? r
                    : (prev.lastEvent.originServerTs <
                            r.lastEvent.originServerTs
                        ? r
                        : prev))
            .id;
      }
    }
    for (final room in rooms) {
      if (room.membership == Membership.invite &&
          room.getState(EventTypes.RoomMember, userID)?.senderId == userId &&
          room.getState(EventTypes.RoomMember, userID).content['is_direct'] ==
              true) {
        return room.id;
      }
    }
    return null;
  }

  /// Gets discovery information about the domain. The file may include additional keys.
  Future<WellKnownInformation> getWellKnownInformationsByUserId(
    String MatrixIdOrDomain,
  ) async {
    final response = await http
        .get(Uri.https(MatrixIdOrDomain.domain, '/.well-known/matrix/client'));
    var respBody = response.body;
    try {
      respBody = utf8.decode(response.bodyBytes);
    } catch (_) {
      // No-OP
    }
    final rawJson = json.decode(respBody);
    return WellKnownInformation.fromJson(rawJson);
  }

  @Deprecated('Use [checkHomeserver] instead.')
  Future<bool> checkServer(dynamic serverUrl) async {
    try {
      await checkHomeserver(serverUrl);
    } catch (_) {
      return false;
    }
    return true;
  }

  /// Checks the supported versions of the Matrix protocol and the supported
  /// login types. Throws an exception if the server is not compatible with the
  /// client and sets [homeserver] to [homeserverUrl] if it is. Supports the
  /// types `Uri` and `String`.
  Future<WellKnownInformation> checkHomeserver(dynamic homeserverUrl,
      {bool checkWellKnown = true}) async {
    try {
      if (homeserverUrl is Uri) {
        homeserver = homeserverUrl;
      } else {
        // URLs allow to have whitespace surrounding them, see https://www.w3.org/TR/2011/WD-html5-20110525/urls.html
        // As we want to strip a trailing slash, though, we have to trim the url ourself
        // and thus can't let Uri.parse() deal with it.
        homeserverUrl = homeserverUrl.trim();
        // strip a trailing slash
        if (homeserverUrl.endsWith('/')) {
          homeserverUrl = homeserverUrl.substring(0, homeserverUrl.length - 1);
        }
        homeserver = Uri.parse(homeserverUrl);
      }

      // Look up well known
      WellKnownInformation wellKnown;
      if (checkWellKnown) {
        try {
          wellKnown = await requestWellKnownInformation();
          homeserverUrl = wellKnown.mHomeserver.baseUrl.trim();
          // strip a trailing slash
          if (homeserverUrl.endsWith('/')) {
            homeserverUrl =
                homeserverUrl.substring(0, homeserverUrl.length - 1);
          }
          homeserver = Uri.parse(homeserverUrl);
        } catch (e) {
          Logs().v('Found no well known information', e);
        }
      }

      // Check if server supports at least one supported version
      final versions = await requestSupportedVersions();
      if (!versions.versions
          .any((version) => supportedVersions.contains(version))) {
        throw BadServerVersionsException(
            versions.versions.toSet(), supportedVersions);
      }

      final loginTypes = await requestLoginTypes();
      if (!loginTypes.flows.any((f) => supportedLoginTypes.contains(f.type))) {
        throw BadServerLoginTypesException(
            loginTypes.flows.map((f) => f.type).toSet(), supportedLoginTypes);
      }

      return wellKnown;
    } catch (_) {
      homeserver = null;
      rethrow;
    }
  }

  /// Checks to see if a username is available, and valid, for the server.
  /// Returns the fully-qualified Matrix user ID (MXID) that has been registered.
  /// You have to call [checkHomeserver] first to set a homeserver.
  @override
  Future<LoginResponse> register({
    String username,
    String password,
    String deviceId,
    String initialDeviceDisplayName,
    bool inhibitLogin,
    AuthenticationData auth,
    String kind,
  }) async {
    final response = await super.register(
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
      throw Exception('Registered but token, device ID or user ID is null.');
    }
    await init(
        newToken: response.accessToken,
        newUserID: response.userId,
        newHomeserver: homeserver,
        newDeviceName: initialDeviceDisplayName ?? '',
        newDeviceID: response.deviceId);
    return response;
  }

  /// Handles the login and allows the client to call all APIs which require
  /// authentication. Returns false if the login was not successful. Throws
  /// MatrixException if login was not successful.
  /// To just login with the username 'alice' you set [identifier] to:
  /// `AuthenticationUserIdentifier(user: 'alice')`
  /// Maybe you want to set [user] to the same String to stay compatible with
  /// older server versions.
  @override
  Future<LoginResponse> login({
    String type = AuthenticationTypes.password,
    AuthenticationIdentifier identifier,
    String password,
    String token,
    String deviceId,
    String initialDeviceDisplayName,
    AuthenticationData auth,
    @Deprecated('Deprecated in favour of identifier.') String user,
    @Deprecated('Deprecated in favour of identifier.') String medium,
    @Deprecated('Deprecated in favour of identifier.') String address,
  }) async {
    if (homeserver == null && user.isValidMatrixId) {
      await checkHomeserver(user.domain);
    }
    final loginResp = await super.login(
      type: type,
      identifier: identifier,
      password: password,
      token: token,
      deviceId: deviceId,
      initialDeviceDisplayName: initialDeviceDisplayName,
      auth: auth,
      // ignore: deprecated_member_use
      user: user,
      // ignore: deprecated_member_use
      medium: medium,
      // ignore: deprecated_member_use
      address: address,
    );

    // Connect if there is an access token in the response.
    if (loginResp.accessToken == null ||
        loginResp.deviceId == null ||
        loginResp.userId == null) {
      throw Exception('Registered but token, device ID or user ID is null.');
    }
    await init(
      newToken: loginResp.accessToken,
      newUserID: loginResp.userId,
      newHomeserver: homeserver,
      newDeviceName: initialDeviceDisplayName ?? '',
      newDeviceID: loginResp.deviceId,
    );
    return loginResp;
  }

  /// Sends a logout command to the homeserver and clears all local data,
  /// including all persistent data from the store.
  @override
  Future<void> logout() async {
    try {
      await super.logout();
    } catch (e, s) {
      Logs().e('Logout failed', e, s);
      rethrow;
    } finally {
      clear();
    }
  }

  /// Sends a logout command to the homeserver and clears all local data,
  /// including all persistent data from the store.
  @override
  Future<void> logoutAll() async {
    try {
      await super.logoutAll();
    } catch (e, s) {
      Logs().e('Logout all failed', e, s);
      rethrow;
    } finally {
      clear();
    }
  }

  /// Run any request and react on user interactive authentication flows here.
  Future<T> uiaRequestBackground<T>(
      Future<T> Function(AuthenticationData auth) request) {
    final completer = Completer<T>();
    UiaRequest uia;
    uia = UiaRequest(
      request: request,
      onUpdate: (state) {
        if (state == UiaRequestState.done) {
          completer.complete(uia.result);
        } else if (state == UiaRequestState.fail) {
          completer.completeError(uia.error);
        } else {
          onUiaRequest.add(uia);
        }
      },
    );
    return completer.future;
  }

  /// Returns an existing direct room ID with this user or creates a new one.
  /// Returns null on error.
  Future<String> startDirectChat(String mxid) async {
    // Try to find an existing direct chat
    var roomId = getDirectChatFromUserId(mxid);
    if (roomId != null) return roomId;

    // Start a new direct chat
    roomId = await createRoom(
      invite: [mxid],
      isDirect: true,
      preset: CreateRoomPreset.trusted_private_chat,
    );

    if (roomId == null) return roomId;

    await Room(id: roomId, client: this).addToDirectChat(mxid);

    return roomId;
  }

  /// Creates a new space and returns the Room ID. The parameters are mostly
  /// the same like in [createRoom()].
  /// Be aware that spaces appear in the [rooms] list. You should check if a
  /// room is a space by using the `room.isSpace` getter and then just use the
  /// room as a space with `room.toSpace()`.
  ///
  /// https://github.com/matrix-org/matrix-doc/blob/matthew/msc1772/proposals/1772-groups-as-rooms.md
  Future<String> createSpace({
    String name,
    String topic,
    Visibility visibility = Visibility.public,
    String spaceAliasName,
    List<String> invite,
    List<Map<String, dynamic>> invite3pid,
    String roomVersion,
  }) =>
      createRoom(
        name: name,
        topic: topic,
        visibility: visibility,
        roomAliasName: spaceAliasName,
        creationContent: {'type': 'm.space'},
        powerLevelContentOverride: {'events_default': 100},
        invite: invite,
        invite3pid: invite3pid,
        roomVersion: roomVersion,
      );

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
    final profile = await requestProfile(userId);
    _profileCache[userId] = profile;
    return profile;
  }

  Future<List<Room>> get archive async {
    var archiveList = <Room>[];
    final syncResp = await sync(
      filter: '{"room":{"include_leave":true,"timeline":{"limit":10}}}',
      timeout: 0,
    );
    if (syncResp.rooms.leave is Map<String, dynamic>) {
      for (var entry in syncResp.rooms.leave.entries) {
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
            leftRoom.setState(Event.fromMatrixEvent(
              event,
              leftRoom,
              sortOrder: event.originServerTs.millisecondsSinceEpoch.toDouble(),
            ));
          }
        }
        if (room.state != null) {
          for (var event in room.state) {
            leftRoom.setState(Event.fromMatrixEvent(
              event,
              leftRoom,
              sortOrder: event.originServerTs.millisecondsSinceEpoch.toDouble(),
            ));
          }
        }
        archiveList.add(leftRoom);
      }
    }
    return archiveList;
  }

  /// Uploads a file and automatically caches it in the database, if it is small enough
  /// and returns the mxc url as a string.
  @override
  Future<String> upload(Uint8List file, String fileName,
      {String contentType}) async {
    final mxc = await super.upload(file, fileName, contentType: contentType);
    final storeable = database != null && file.length <= database.maxFileSize;
    if (storeable) {
      await database.storeFile(
          mxc, file, DateTime.now().millisecondsSinceEpoch);
    }
    return mxc;
  }

  /// Sends a typing notification and initiates a megolm session, if needed
  @override
  Future<void> sendTypingNotification(
    String userId,
    String roomId,
    bool typing, {
    int timeout,
  }) async {
    await super
        .sendTypingNotification(userId, roomId, typing, timeout: timeout);
    final room = getRoomById(roomId);
    if (typing && room != null && encryptionEnabled && room.encrypted) {
      unawaited(encryption.keyManager.prepareOutboundGroupSession(roomId));
    }
  }

  /// Uploads a new user avatar for this user.
  Future<void> setAvatar(MatrixFile file) async {
    final uploadResp = await upload(file.bytes, file.name);
    await setAvatarUrl(userID, Uri.parse(uploadResp));
    return;
  }

  /// Returns the global push rules for the logged in user.
  PushRuleSet get globalPushRules => accountData.containsKey('m.push_rules')
      ? PushRuleSet.fromJson(accountData['m.push_rules'].content['global'])
      : null;

  /// Returns the device push rules for the logged in user.
  PushRuleSet get devicePushRules => accountData.containsKey('m.push_rules')
      ? PushRuleSet.fromJson(accountData['m.push_rules'].content['device'])
      : null;

  static const Set<String> supportedVersions = {'r0.5.0', 'r0.6.0'};
  static const List<String> supportedDirectEncryptionAlgorithms = [
    AlgorithmTypes.olmV1Curve25519AesSha2
  ];
  static const List<String> supportedGroupEncryptionAlgorithms = [
    AlgorithmTypes.megolmV1AesSha2
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

  /// Called when the local cache is reset
  final StreamController<bool> onCacheCleared = StreamController.broadcast();

  /// Synchronization errors are coming here.
  final StreamController<SdkError> onSyncError = StreamController.broadcast();

  /// Encryption errors are coming here.
  final StreamController<SdkError> onEncryptionError =
      StreamController.broadcast();

  /// This is called once, when the first sync has been processed.
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

  /// When the library calls an endpoint that needs UIA the `UiaRequest` is passed down this screen.
  /// The client can open a UIA prompt based on this.
  final StreamController<UiaRequest> onUiaRequest =
      StreamController.broadcast();

  /// How long should the app wait until it retrys the synchronisation after
  /// an error?
  int syncErrorTimeoutSec = 3;

  @Deprecated('Use init() instead')
  void connect({
    String newToken,
    Uri newHomeserver,
    String newUserID,
    String newDeviceName,
    String newDeviceID,
    String newOlmAccount,
  }) =>
      init(
        newToken: newToken,
        newHomeserver: newHomeserver,
        newUserID: newUserID,
        newDeviceName: newDeviceName,
        newDeviceID: newDeviceID,
        newOlmAccount: newOlmAccount,
      );

  bool _initLock = false;

  /// Sets the user credentials and starts the synchronisation.
  ///
  /// Before you can connect you need at least an [accessToken], a [homeserver],
  /// a [userID], a [deviceID], and a [deviceName].
  ///
  /// Usually you don't need to call this method by yourself because [login()], [register()]
  /// and even the constructor calls it.
  ///
  /// Sends [LoginState.logged] to [onLoginStateChanged].
  ///
  /// If one of [newToken], [newUserID], [newDeviceID], [newDeviceName] is set then
  /// all of them must be set! If you don't set them, this method will try to
  /// get them from the database.
  Future<void> init({
    String newToken,
    Uri newHomeserver,
    String newUserID,
    String newDeviceName,
    String newDeviceID,
    String newOlmAccount,
  }) async {
    if ((newToken != null ||
            newUserID != null ||
            newDeviceID != null ||
            newDeviceName != null) &&
        (newToken == null ||
            newUserID == null ||
            newDeviceID == null ||
            newDeviceName == null)) {
      throw Exception(
          'If one of [newToken, newUserID, newDeviceID, newDeviceName] is set then all of them must be set!');
    }

    if (_initLock) throw Exception('[init()] has been called multiple times!');
    _initLock = true;
    try {
      Logs().i('Initialize client $clientName');
      if (isLogged()) {
        throw Exception('User is already logged in! Call [logout()] first!');
      }

      if (databaseBuilder != null) {
        _database ??= await databaseBuilder(this);
      }

      String olmAccount;
      if (database != null) {
        final account = await database.getClient(clientName);
        if (account != null) {
          _id = account.clientId;
          homeserver = Uri.parse(account.homeserverUrl);
          accessToken = account.token;
          _userID = account.userId;
          _deviceID = account.deviceId;
          _deviceName = account.deviceName;
          syncFilterId = account.syncFilterId;
          prevBatch = account.prevBatch;
          olmAccount = account.olmAccount;
        }
      }
      if (newToken != null) {
        accessToken = newToken;
        homeserver = newHomeserver;
        _userID = newUserID;
        _deviceID = newDeviceID;
        _deviceName = newDeviceName;
        olmAccount = newOlmAccount;
      } else {
        accessToken = newToken ?? accessToken;
        homeserver = newHomeserver ?? homeserver;
        _userID = newUserID ?? _userID;
        _deviceID = newDeviceID ?? _deviceID;
        _deviceName = newDeviceName ?? _deviceName;
        olmAccount = newOlmAccount ?? olmAccount;
      }

      if (accessToken == null || homeserver == null || _userID == null) {
        // we aren't logged in
        encryption?.dispose();
        encryption = null;
        onLoginStateChanged.add(LoginState.loggedOut);
        Logs().i('User is not logged in.');
        _initLock = false;
        return;
      }
      _initLock = false;

      encryption?.dispose();
      try {
        // make sure to throw an exception if libolm doesn't exist
        await olm.init();
        olm.get_library_version();
        encryption =
            Encryption(client: this, enableE2eeRecovery: enableE2eeRecovery);
      } catch (_) {
        encryption?.dispose();
        encryption = null;
      }
      await encryption?.init(olmAccount);

      if (database != null) {
        if (id != null) {
          await database.updateClient(
            homeserver.toString(),
            accessToken,
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
            homeserver.toString(),
            accessToken,
            _userID,
            _deviceID,
            _deviceName,
            prevBatch,
            encryption?.pickledOlmAccount,
          );
        }
        _userDeviceKeys = await database.getUserDeviceKeys(this);
        _rooms = await database.getRoomList(this, onlyLeft: false);
        _sortRooms();
        accountData = await database.getAccountData(id);
        presences.clear();
      }

      onLoginStateChanged.add(LoginState.logged);
      Logs().i(
        'Successfully connected as ${userID.localpart} with ${homeserver.toString()}',
      );
      return _sync();
    } catch (e, s) {
      Logs().e('Initialization failed', e, s);
      await logout().catchError((_) => null);
      onLoginStateChanged.addError(e, s);
      _initLock = false;
      rethrow;
    }
  }

  /// Used for testing only
  void setUserId(String s) {
    _userID = s;
  }

  /// Resets all settings and stops the synchronisation.
  void clear() {
    Logs().outputEvents.clear();
    database?.clear(id);
    _id = accessToken = syncFilterId =
        homeserver = _userID = _deviceID = _deviceName = prevBatch = null;
    _rooms = [];
    encryption?.dispose();
    encryption = null;
    onLoginStateChanged.add(LoginState.loggedOut);
  }

  bool _backgroundSync = true;
  Future<void> _currentSync, _retryDelay = Future.value();

  bool get syncPending => _currentSync != null;

  /// Controls the background sync (automatically looping forever if turned on).
  set backgroundSync(bool enabled) {
    _backgroundSync = enabled;
    if (_backgroundSync) {
      _sync();
    }
  }

  /// Immediately start a sync and wait for completion.
  /// If there is an active sync already, wait for the active sync instead.
  Future<void> oneShotSync() {
    return _sync();
  }

  Future<void> _sync() {
    if (_currentSync == null) {
      _currentSync = _innerSync();
      _currentSync.whenComplete(() {
        _currentSync = null;
        if (_backgroundSync && isLogged() && !_disposed) {
          _sync();
        }
      });
    }
    return _currentSync;
  }

  /// Presence that is set on sync.
  PresenceType syncPresence;

  Future<void> _checkSyncFilter() async {
    if (syncFilterId == null) {
      syncFilterId = await uploadFilter(userID, syncFilter);
      await database?.storeSyncFilterId(syncFilterId, id);
    }
    return;
  }

  Future<void> _innerSync() async {
    await _retryDelay;
    _retryDelay = Future.delayed(Duration(seconds: syncErrorTimeoutSec));
    if (!isLogged() || _disposed || _aborted) return null;
    try {
      var syncError;
      await _checkSyncFilter();
      final syncRequest = sync(
        filter: syncFilterId,
        since: prevBatch,
        timeout: prevBatch != null ? 30000 : null,
        setPresence: syncPresence,
      ).catchError((e) {
        syncError = e;
        return null;
      });
      _currentSyncId = syncRequest.hashCode;
      final syncResp = await syncRequest;
      if (syncResp == null) throw syncError ?? 'Unknown sync error';
      if (_currentSyncId != syncRequest.hashCode) {
        Logs()
            .w('Current sync request ID has changed. Dropping this sync loop!');
        return;
      }
      if (database != null) {
        _currentTransaction = database.transaction(() async {
          await handleSync(syncResp);
          if (prevBatch != syncResp.nextBatch) {
            await database.storePrevBatch(syncResp.nextBatch, id);
          }
        });
        await _currentTransaction;
      } else {
        await handleSync(syncResp);
      }
      if (_disposed || _aborted) return;
      if (prevBatch == null) {
        onFirstSync.add(true);
        prevBatch = syncResp.nextBatch;
        _sortRooms();
      }
      prevBatch = syncResp.nextBatch;
      await database?.deleteOldFiles(
          DateTime.now().subtract(Duration(days: 30)).millisecondsSinceEpoch);
      await _updateUserDeviceKeys();
      if (encryptionEnabled) {
        encryption.onSync();
      }

      // try to process the to_device queue
      try {
        await processToDeviceQueue();
      } catch (_) {} // we want to dispose any errors this throws

      _retryDelay = Future.value();
    } on MatrixException catch (e, s) {
      onSyncError.add(SdkError(exception: e, stackTrace: s));
      if (e.error == MatrixError.M_UNKNOWN_TOKEN) {
        Logs().w('The user has been logged out!');
        clear();
      }
    } on MatrixConnectionException catch (e, s) {
      Logs().w('Synchronization connection failed');
      onSyncError.add(SdkError(exception: e, stackTrace: s));
    } catch (e, s) {
      if (!isLogged() || _disposed || _aborted) return;
      Logs().e('Error during processing events', e, s);
      onSyncError.add(SdkError(
          exception: e is Exception ? e : Exception(e), stackTrace: s));
    }
  }

  /// Use this method only for testing utilities!
  Future<void> handleSync(SyncUpdate sync, {bool sortAtTheEnd = false}) async {
    if (sync.toDevice != null) {
      await _handleToDeviceEvents(sync.toDevice);
    }
    if (sync.rooms != null) {
      if (sync.rooms.join != null) {
        await _handleRooms(sync.rooms.join, Membership.join,
            sortAtTheEnd: sortAtTheEnd);
      }
      if (sync.rooms.invite != null) {
        await _handleRooms(sync.rooms.invite, Membership.invite,
            sortAtTheEnd: sortAtTheEnd);
      }
      if (sync.rooms.leave != null) {
        await _handleRooms(sync.rooms.leave, Membership.leave,
            sortAtTheEnd: sortAtTheEnd);
      }
      _sortRooms();
    }
    if (sync.presence != null) {
      for (final newPresence in sync.presence) {
        presences[newPresence.senderId] = newPresence;
        onPresence.add(newPresence);
      }
    }
    if (sync.accountData != null) {
      for (final newAccountData in sync.accountData) {
        if (database != null) {
          await database.storeAccountData(
            id,
            newAccountData.type,
            jsonEncode(newAccountData.content),
          );
        }
        accountData[newAccountData.type] = newAccountData;
        if (onAccountData != null) onAccountData.add(newAccountData);
      }
    }
    if (sync.deviceLists != null) {
      await _handleDeviceListsEvents(sync.deviceLists);
    }
    if ((sync.deviceUnusedFallbackKeyTypes != null ||
            sync.deviceOneTimeKeysCount != null) &&
        encryptionEnabled) {
      encryption.handleDeviceOneTimeKeysCount(
          sync.deviceOneTimeKeysCount, sync.deviceUnusedFallbackKeyTypes);
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
    for (final event in events) {
      var toDeviceEvent = ToDeviceEvent.fromJson(event.toJson());
      Logs().v('Got to_device event of type ${toDeviceEvent.type}');
      if (toDeviceEvent.type == EventTypes.Encrypted && encryptionEnabled) {
        toDeviceEvent = await encryption.decryptToDeviceEvent(toDeviceEvent);
        Logs().v('Decrypted type is: ${toDeviceEvent.type}');
      }
      if (encryptionEnabled) {
        await encryption.handleToDeviceEvent(toDeviceEvent);
      }
      onToDeviceEvent.add(toDeviceEvent);
    }
  }

  Future<void> _handleRooms(
      Map<String, SyncRoomUpdate> rooms, Membership membership,
      {bool sortAtTheEnd = false}) async {
    for (final entry in rooms.entries) {
      final id = entry.key;
      final room = entry.value;

      var update = RoomUpdate.fromSyncRoomUpdate(room, id);
      if (database != null) {
        // TODO: This method seems to be rather slow for some updates
        // Perhaps don't dynamically build that one query?
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
          // TODO: This method seems to be comperatively slow for some updates
          await _handleRoomEvents(id,
              room.state.map((i) => i.toJson()).toList(), EventUpdateType.state,
              sortAtTheEnd: sortAtTheEnd);
          handledEvents = true;
        }
        if (room.timeline?.events?.isNotEmpty ?? false) {
          await _handleRoomEvents(
              id,
              room.timeline.events.map((i) => i.toJson()).toList(),
              sortAtTheEnd ? EventUpdateType.history : EventUpdateType.timeline,
              sortAtTheEnd: sortAtTheEnd);
          handledEvents = true;
        }
        if (room.ephemeral?.isNotEmpty ?? false) {
          // TODO: This method seems to be comperatively slow for some updates
          await _handleEphemerals(
              id, room.ephemeral.map((i) => i.toJson()).toList());
        }
        if (room.accountData?.isNotEmpty ?? false) {
          await _handleRoomEvents(
              id,
              room.accountData.map((i) => i.toJson()).toList(),
              EventUpdateType.accountData);
        }
      }
      if (room is LeftRoomUpdate) {
        if (room.timeline?.events?.isNotEmpty ?? false) {
          await _handleRoomEvents(
              id,
              room.timeline.events.map((i) => i.toJson()).toList(),
              EventUpdateType.timeline);
          handledEvents = true;
        }
        if (room.accountData?.isNotEmpty ?? false) {
          await _handleRoomEvents(
              id,
              room.accountData.map((i) => i.toJson()).toList(),
              EventUpdateType.accountData);
        }
        if (room.state?.isNotEmpty ?? false) {
          await _handleRoomEvents(
              id,
              room.state.map((i) => i.toJson()).toList(),
              EventUpdateType.state);
          handledEvents = true;
        }
      }
      if (room is InvitedRoomUpdate &&
          (room.inviteState?.isNotEmpty ?? false)) {
        await _handleRoomEvents(
            id,
            room.inviteState.map((i) => i.toJson()).toList(),
            EventUpdateType.inviteState);
      }
      if (handledEvents && database != null && roomObj != null) {
        await roomObj.updateSortOrder();
      }
    }
  }

  Future<void> _handleEphemerals(String id, List<dynamic> events) async {
    for (final event in events) {
      await _handleEvent(event, id, EventUpdateType.ephemeral);

      // Receipt events are deltas between two states. We will create a
      // fake room account data event for this and store the difference
      // there.
      if (event['type'] == 'm.receipt') {
        var room = getRoomById(id);
        room ??= Room(id: id);

        var receiptStateContent =
            room.roomAccountData['m.receipt']?.content ?? {};
        for (var eventEntry in event['content'].entries) {
          final String eventID = eventEntry.key;
          if (event['content'][eventID]['m.read'] != null) {
            final Map<String, dynamic> userTimestampMap =
                event['content'][eventID]['m.read'];
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
        event['content'] = receiptStateContent;
        await _handleEvent(event, id, EventUpdateType.accountData);
      }
    }
  }

  Future<void> _handleRoomEvents(
      String chat_id, List<dynamic> events, EventUpdateType type,
      {bool sortAtTheEnd = false}) async {
    for (final event in events) {
      await _handleEvent(event, chat_id, type, sortAtTheEnd: sortAtTheEnd);
    }
  }

  Future<void> _handleEvent(
      Map<String, dynamic> event, String roomID, EventUpdateType type,
      {bool sortAtTheEnd = false}) async {
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
      final sortOrder = type != EventUpdateType.ephemeral
          ? (sortAtTheEnd ? room.oldSortOrder : room.newSortOrder)
          : 0.0;
      var update = EventUpdate(
        roomID: roomID,
        type: type,
        content: event,
        sortOrder: sortOrder,
      );
      if (event['type'] == EventTypes.Encrypted && encryptionEnabled) {
        update = await update.decrypt(room);
      }
      if (event['type'] == EventTypes.Message &&
          !room.isDirectChat &&
          database != null &&
          room.getState(EventTypes.RoomMember, event['sender']) == null) {
        // In order to correctly render room list previews we need to fetch the member from the database
        final user = await database.getUser(id, event['sender'], room);
        if (user != null) {
          room.setState(user);
        }
      }
      if (type != EventUpdateType.ephemeral && database != null) {
        await database.storeEventUpdate(id, update);
      }
      _updateRoomsByEventUpdate(update);
      if (encryptionEnabled) {
        await encryption.handleEventUpdate(update);
      }
      onEvent.add(update);

      final rawUnencryptedEvent = update.content;

      if (prevBatch != null && type == EventUpdateType.timeline) {
        if (rawUnencryptedEvent['type'] == EventTypes.CallInvite) {
          onCallInvite
              .add(Event.fromJson(rawUnencryptedEvent, room, sortOrder));
        } else if (rawUnencryptedEvent['type'] == EventTypes.CallHangup) {
          onCallHangup
              .add(Event.fromJson(rawUnencryptedEvent, room, sortOrder));
        } else if (rawUnencryptedEvent['type'] == EventTypes.CallAnswer) {
          onCallAnswer
              .add(Event.fromJson(rawUnencryptedEvent, room, sortOrder));
        } else if (rawUnencryptedEvent['type'] == EventTypes.CallCandidates) {
          onCallCandidates
              .add(Event.fromJson(rawUnencryptedEvent, room, sortOrder));
        }
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
      if (chatUpdate.limitedTimeline && requestHistoryOnLimitedTimeline) {
        Logs().v('Limited timeline for ${rooms[j].id} request history now');
        runInRoot(rooms[j].requestHistory);
      }
    }
  }

  void _updateRoomsByEventUpdate(EventUpdate eventUpdate) {
    if (eventUpdate.type == EventUpdateType.history) return;

    final room = getRoomById(eventUpdate.roomID);
    if (room == null) return;

    switch (eventUpdate.type) {
      case EventUpdateType.timeline:
      case EventUpdateType.state:
      case EventUpdateType.inviteState:
        var stateEvent =
            Event.fromJson(eventUpdate.content, room, eventUpdate.sortOrder);
        var prevState = room.getState(stateEvent.type, stateEvent.stateKey);
        if (eventUpdate.type == EventUpdateType.timeline &&
            prevState != null &&
            prevState.sortOrder > stateEvent.sortOrder) {
          Logs().w('''
A new ${eventUpdate.type} event of the type ${stateEvent.type} has arrived with a previews
sort order ${stateEvent.sortOrder} than the current ${stateEvent.type} event with a
sort order of ${prevState.sortOrder}. This should never happen...''');
          return;
        }
        if (stateEvent.type == EventTypes.Redaction) {
          final String redacts = eventUpdate.content['redacts'];
          room.states.forEach(
            (String key, Map<String, Event> states) => states.forEach(
              (String key, Event state) {
                if (state.eventId == redacts) {
                  state.setRedactionEvent(stateEvent);
                }
              },
            ),
          );
        } else {
          room.setState(stateEvent);
        }
        break;
      case EventUpdateType.accountData:
        room.roomAccountData[eventUpdate.content['type']] =
            BasicRoomEvent.fromJson(eventUpdate.content);
        break;
      case EventUpdateType.ephemeral:
        room.ephemerals[eventUpdate.content['type']] =
            BasicRoomEvent.fromJson(eventUpdate.content);
        break;
      case EventUpdateType.history:
        break;
    }
    room.onUpdate.add(room.id);
  }

  bool _sortLock = false;

  /// If `true` then unread rooms are pinned at the top of the room list.
  bool pinUnreadRooms;

  /// The compare function how the rooms should be sorted internally. By default
  /// rooms are sorted by timestamp of the last m.room.message event or the last
  /// event if there is no known message.
  RoomSorter get sortRoomsBy => (a, b) => (a.isFavourite != b.isFavourite)
      ? (a.isFavourite ? -1 : 1)
      : (pinUnreadRooms && a.notificationCount != b.notificationCount)
          ? b.notificationCount.compareTo(a.notificationCount)
          : b.timeCreated.millisecondsSinceEpoch
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

  /// Gets user device keys by its curve25519 key. Returns null if it isn't found
  DeviceKeys getUserDeviceKeysByCurve25519Key(String senderKey) {
    for (final user in userDeviceKeys.values) {
      final device = user.deviceKeys.values
          .firstWhere((e) => e.curve25519Key == senderKey, orElse: () => null);
      if (device != null) {
        return device;
      }
    }
    return null;
  }

  Future<Set<String>> _getUserIdsInEncryptedRooms() async {
    var userIds = <String>{};
    for (final room in rooms) {
      if (room.encrypted) {
        try {
          var userList = await room.requestParticipants();
          for (var user in userList) {
            if ([Membership.join, Membership.invite]
                .contains(user.membership)) {
              userIds.add(user.id);
            }
          }
        } catch (e, s) {
          Logs().e('[E2EE] Failed to fetch participants', e, s);
        }
      }
    }
    return userIds;
  }

  final Map<String, DateTime> _keyQueryFailures = {};

  Future<void> _updateUserDeviceKeys() async {
    try {
      if (!isLogged()) return;
      final dbActions = <Future<dynamic> Function()>[];
      var trackedUserIds = await _getUserIdsInEncryptedRooms();
      if (!isLogged()) return;
      trackedUserIds.add(userID);

      // Remove all userIds we no longer need to track the devices of.
      _userDeviceKeys
          .removeWhere((String userId, v) => !trackedUserIds.contains(userId));

      // Check if there are outdated device key lists. Add it to the set.
      var outdatedLists = <String, dynamic>{};
      for (var userId in trackedUserIds) {
        if (!userDeviceKeys.containsKey(userId)) {
          _userDeviceKeys[userId] = DeviceKeysList(userId, this);
        }
        var deviceKeysList = userDeviceKeys[userId];
        if (deviceKeysList.outdated &&
            (!_keyQueryFailures.containsKey(userId.domain) ||
                DateTime.now()
                    .subtract(Duration(minutes: 5))
                    .isAfter(_keyQueryFailures[userId.domain]))) {
          outdatedLists[userId] = [];
        }
      }

      if (outdatedLists.isNotEmpty) {
        // Request the missing device key lists from the server.
        final response = await requestDeviceKeys(outdatedLists, timeout: 10000);
        if (!isLogged()) return;

        for (final rawDeviceKeyListEntry in response.deviceKeys.entries) {
          final userId = rawDeviceKeyListEntry.key;
          if (!userDeviceKeys.containsKey(userId)) {
            _userDeviceKeys[userId] = DeviceKeysList(userId, this);
          }
          final oldKeys =
              Map<String, DeviceKeys>.from(_userDeviceKeys[userId].deviceKeys);
          _userDeviceKeys[userId].deviceKeys = {};
          for (final rawDeviceKeyEntry in rawDeviceKeyListEntry.value.entries) {
            final deviceId = rawDeviceKeyEntry.key;

            // Set the new device key for this device
            final entry = DeviceKeys.fromMatrixDeviceKeys(
                rawDeviceKeyEntry.value, this, oldKeys[deviceId]?.lastActive);
            if (entry.isValid) {
              // is this a new key or the same one as an old one?
              // better store an update - the signatures might have changed!
              if (!oldKeys.containsKey(deviceId) ||
                  oldKeys[deviceId].ed25519Key == entry.ed25519Key) {
                if (oldKeys.containsKey(deviceId)) {
                  // be sure to save the verified status
                  entry.setDirectVerified(oldKeys[deviceId].directVerified);
                  entry.blocked = oldKeys[deviceId].blocked;
                  entry.validSignatures = oldKeys[deviceId].validSignatures;
                }
                _userDeviceKeys[userId].deviceKeys[deviceId] = entry;
                if (deviceId == deviceID &&
                    entry.ed25519Key == fingerprintKey) {
                  // Always trust the own device
                  entry.setDirectVerified(true);
                }
                if (database != null) {
                  dbActions.add(() => database.storeUserDeviceKey(
                        id,
                        userId,
                        deviceId,
                        json.encode(entry.toJson()),
                        entry.directVerified,
                        entry.blocked,
                        entry.lastActive.millisecondsSinceEpoch,
                      ));
                }
              } else if (oldKeys.containsKey(deviceId)) {
                // This shouldn't ever happen. The same device ID has gotten
                // a new public key. So we ignore the update. TODO: ask krille
                // if we should instead use the new key with unknown verified / blocked status
                _userDeviceKeys[userId].deviceKeys[deviceId] =
                    oldKeys[deviceId];
              }
            } else {
              Logs().w('Invalid device ${entry.userId}:${entry.deviceId}');
            }
          }
          // delete old/unused entries
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
        // next we parse and persist the cross signing keys
        final crossSigningTypes = {
          'master': response.masterKeys,
          'self_signing': response.selfSigningKeys,
          'user_signing': response.userSigningKeys,
        };
        for (final crossSigningKeysEntry in crossSigningTypes.entries) {
          final keyType = crossSigningKeysEntry.key;
          final keys = crossSigningKeysEntry.value;
          if (keys == null) {
            continue;
          }
          for (final crossSigningKeyListEntry in keys.entries) {
            final userId = crossSigningKeyListEntry.key;
            if (!userDeviceKeys.containsKey(userId)) {
              _userDeviceKeys[userId] = DeviceKeysList(userId, this);
            }
            final oldKeys = Map<String, CrossSigningKey>.from(
                _userDeviceKeys[userId].crossSigningKeys);
            _userDeviceKeys[userId].crossSigningKeys = {};
            // add the types we aren't handling atm back
            for (final oldEntry in oldKeys.entries) {
              if (!oldEntry.value.usage.contains(keyType)) {
                _userDeviceKeys[userId].crossSigningKeys[oldEntry.key] =
                    oldEntry.value;
              } else if (database != null) {
                // There is a previous cross-signing key with  this usage, that we no
                // longer need/use. Clear it from the database.
                dbActions.add(() => database.removeUserCrossSigningKey(
                    id, userId, oldEntry.key));
              }
            }
            final entry = CrossSigningKey.fromMatrixCrossSigningKey(
                crossSigningKeyListEntry.value, this);
            if (entry.isValid) {
              final publicKey = entry.publicKey;
              if (!oldKeys.containsKey(publicKey) ||
                  oldKeys[publicKey].ed25519Key == entry.ed25519Key) {
                if (oldKeys.containsKey(publicKey)) {
                  // be sure to save the verification status
                  entry.setDirectVerified(oldKeys[publicKey].directVerified);
                  entry.blocked = oldKeys[publicKey].blocked;
                  entry.validSignatures = oldKeys[publicKey].validSignatures;
                }
                _userDeviceKeys[userId].crossSigningKeys[publicKey] = entry;
              } else {
                // This shouldn't ever happen. The same device ID has gotten
                // a new public key. So we ignore the update. TODO: ask krille
                // if we should instead use the new key with unknown verified / blocked status
                _userDeviceKeys[userId].crossSigningKeys[publicKey] =
                    oldKeys[publicKey];
              }
              if (database != null) {
                dbActions.add(() => database.storeUserCrossSigningKey(
                      id,
                      userId,
                      publicKey,
                      json.encode(entry.toJson()),
                      entry.directVerified,
                      entry.blocked,
                    ));
              }
            }
            _userDeviceKeys[userId].outdated = false;
            if (database != null) {
              dbActions.add(
                  () => database.storeUserDeviceKeysInfo(id, userId, false));
            }
          }
        }

        // now process all the failures
        if (response.failures != null) {
          for (final failureDomain in response.failures.keys) {
            _keyQueryFailures[failureDomain] = DateTime.now();
          }
        }
      }

      if (dbActions.isNotEmpty) {
        if (!isLogged()) return;
        await database?.transaction(() async {
          for (final f in dbActions) {
            await f();
          }
        });
      }
    } catch (e, s) {
      Logs().e('[LibOlm] Unable to update user device keys', e, s);
    }
  }

  bool _toDeviceQueueNeedsProcessing = true;

  /// Processes the to_device queue and tries to send every entry.
  /// This function MAY throw an error, which just means the to_device queue wasn't
  /// proccessed all the way.
  Future<void> processToDeviceQueue() async {
    if (database == null || !_toDeviceQueueNeedsProcessing) {
      return;
    }
    final entries = await database.getToDeviceQueue(id).get();
    if (entries.isEmpty) {
      _toDeviceQueueNeedsProcessing = false;
      return;
    }
    for (final entry in entries) {
      // ohgod what is this...
      final data = (json.decode(entry.content) as Map).map((k, v) =>
          MapEntry<String, Map<String, Map<String, dynamic>>>(
              k,
              (v as Map).map((k, v) => MapEntry<String, Map<String, dynamic>>(
                  k, Map<String, dynamic>.from(v)))));
      await super.sendToDevice(entry.type, entry.txnId, data);
      await database.deleteFromToDeviceQueue(id, entry.id);
    }
  }

  /// Sends a raw to_device event with a [eventType], a [txnId] and a content
  /// [messages]. Before sending, it tries to re-send potentially queued
  /// to_device events and adds the current one to the queue, should it fail.
  @override
  Future<void> sendToDevice(
    String eventType,
    String txnId,
    Map<String, Map<String, Map<String, dynamic>>> messages,
  ) async {
    try {
      await processToDeviceQueue();
      await super.sendToDevice(eventType, txnId, messages);
    } catch (e, s) {
      Logs().w(
          '[Client] Problem while sending to_device event, retrying later...',
          e,
          s);
      if (database != null) {
        _toDeviceQueueNeedsProcessing = true;
        await database.insertIntoToDeviceQueue(
            id, eventType, txnId, json.encode(messages));
      }
      rethrow;
    }
  }

  /// Send an (unencrypted) to device [message] of a specific [eventType] to all
  /// devices of a set of [users].
  Future<void> sendToDevicesOfUserIds(
    Set<String> users,
    String eventType,
    Map<String, dynamic> message, {
    String messageId,
  }) async {
    // Send with send-to-device messaging
    var data = <String, Map<String, Map<String, dynamic>>>{};
    for (var user in users) {
      data[user] = {};
      data[user]['*'] = message;
    }
    await sendToDevice(
        eventType, messageId ?? generateUniqueTransactionId(), data);
    return;
  }

  /// Sends an encrypted [message] of this [eventType] to these [deviceKeys].
  Future<void> sendToDeviceEncrypted(
    List<DeviceKeys> deviceKeys,
    String eventType,
    Map<String, dynamic> message, {
    String messageId,
    bool onlyVerified = false,
  }) async {
    if (!encryptionEnabled) return;
    // Don't send this message to blocked devices, and if specified onlyVerified
    // then only send it to verified devices
    if (deviceKeys.isNotEmpty) {
      deviceKeys.removeWhere((DeviceKeys deviceKeys) =>
          deviceKeys.blocked ||
          (deviceKeys.userId == userID && deviceKeys.deviceId == deviceID) ||
          (onlyVerified && !deviceKeys.verified));
      if (deviceKeys.isEmpty) return;
    }

    // Send with send-to-device messaging
    var data = <String, Map<String, Map<String, dynamic>>>{};
    data =
        await encryption.encryptToDeviceMessage(deviceKeys, eventType, message);
    eventType = EventTypes.Encrypted;
    await sendToDevice(
        eventType, messageId ?? generateUniqueTransactionId(), data);
  }

  /// Sends an encrypted [message] of this [eventType] to these [deviceKeys].
  /// This request happens partly in the background and partly in the
  /// foreground. It automatically chunks sending to device keys based on
  /// activity.
  Future<void> sendToDeviceEncryptedChunked(
    List<DeviceKeys> deviceKeys,
    String eventType,
    Map<String, dynamic> message,
  ) async {
    if (!encryptionEnabled) return;
    // be sure to copy our device keys list
    deviceKeys = List<DeviceKeys>.from(deviceKeys);
    deviceKeys.removeWhere((DeviceKeys k) =>
        k.blocked || (k.userId == userID && k.deviceId == deviceID));
    if (deviceKeys.isEmpty) return;
    message = message.copy(); // make sure we deep-copy the message
    // make sure all the olm sessions are loaded from database
    Logs().v('Sending to device chunked... (${deviceKeys.length} devices)');
    // sort so that devices we last received messages from get our message first
    deviceKeys.sort((keyA, keyB) => keyB.lastActive.compareTo(keyA.lastActive));
    // and now send out in chunks of 20
    const chunkSize = 20;

    // first we send out all the chunks that we await
    var i = 0;
    // we leave this in a for-loop for now, so that we can easily adjust the break condition
    // based on other things, if we want to hard-`await` more devices in the future
    for (; i < deviceKeys.length && i <= 0; i += chunkSize) {
      Logs().v('Sending chunk $i...');
      final chunk = deviceKeys.sublist(
          i,
          i + chunkSize > deviceKeys.length
              ? deviceKeys.length
              : i + chunkSize);
      // and send
      await sendToDeviceEncrypted(chunk, eventType, message);
    }
    // now send out the background chunks
    if (i < deviceKeys.length) {
      unawaited(() async {
        for (; i < deviceKeys.length; i += chunkSize) {
          // wait 50ms to not freeze the UI
          await Future.delayed(Duration(milliseconds: 50));
          Logs().v('Sending chunk $i...');
          final chunk = deviceKeys.sublist(
              i,
              i + chunkSize > deviceKeys.length
                  ? deviceKeys.length
                  : i + chunkSize);
          // and send
          unawaited(sendToDeviceEncrypted(chunk, eventType, message));
        }
      }());
    }
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
      for (final pushRule in globalPushRules['override']) {
        if (pushRule['rule_id'] == '.m.rule.master') {
          return pushRule['enabled'];
        }
      }
    }
    return false;
  }

  Future<void> setMuteAllPushNotifications(bool muted) async {
    await enablePushRule(
      'global',
      PushRuleKind.override,
      '.m.rule.master',
      muted,
    );
    return;
  }

  /// Changes the password. You should either set oldPasswort or another authentication flow.
  @override
  Future<void> changePassword(String newPassword,
      {String oldPassword, AuthenticationData auth}) async {
    try {
      if (oldPassword != null) {
        auth = AuthenticationPassword(
          user: userID,
          identifier: AuthenticationUserIdentifier(user: userID),
          password: oldPassword,
        );
      }
      await super.changePassword(newPassword, auth: auth);
    } on MatrixException catch (matrixException) {
      if (!matrixException.requireAdditionalAuthentication) {
        rethrow;
      }
      if (matrixException.authenticationFlows.length != 1 ||
          !matrixException.authenticationFlows.first.stages
              .contains(AuthenticationTypes.password)) {
        rethrow;
      }
      if (oldPassword == null) {
        rethrow;
      }
      return changePassword(
        newPassword,
        auth: AuthenticationPassword(
          user: userID,
          identifier: AuthenticationUserIdentifier(user: userID),
          password: oldPassword,
          session: matrixException.session,
        ),
      );
    } catch (_) {
      rethrow;
    }
  }

  @Deprecated('Use clearCache()')
  Future<void> clearLocalCachedMessages() async {
    await clearCache();
  }

  /// Clear all local cached messages, room information and outbound group
  /// sessions and perform a new clean sync.
  Future<void> clearCache() async {
    await abortSync();
    prevBatch = null;
    rooms.clear();
    await database?.clearCache(id);
    encryption?.keyManager?.clearOutboundGroupSessions();
    onCacheCleared.add(true);
    // Restart the syncloop
    backgroundSync = true;
  }

  /// A list of mxids of users who are ignored.
  List<String> get ignoredUsers => (accountData
              .containsKey('m.ignored_user_list') &&
          accountData['m.ignored_user_list'].content['ignored_users'] is Map)
      ? List<String>.from(
          accountData['m.ignored_user_list'].content['ignored_users'].keys)
      : [];

  /// Ignore another user. This will clear the local cached messages to
  /// hide all previous messages from this user.
  Future<void> ignoreUser(String userId) async {
    if (!userId.isValidMatrixId) {
      throw Exception('$userId is not a valid mxid!');
    }
    await setAccountData(userID, 'm.ignored_user_list', {
      'ignored_users': Map.fromEntries(
          (ignoredUsers..add(userId)).map((key) => MapEntry(key, {}))),
    });
    await clearCache();
    return;
  }

  /// Unignore a user. This will clear the local cached messages and request
  /// them again from the server to avoid gaps in the timeline.
  Future<void> unignoreUser(String userId) async {
    if (!userId.isValidMatrixId) {
      throw Exception('$userId is not a valid mxid!');
    }
    if (!ignoredUsers.contains(userId)) {
      throw Exception('$userId is not in the ignore list!');
    }
    await setAccountData(userID, 'm.ignored_user_list', {
      'ignored_users': Map.fromEntries(
          (ignoredUsers..remove(userId)).map((key) => MapEntry(key, {}))),
    });
    await clearCache();
    return;
  }

  bool _disposed = false;
  bool _aborted = false;
  Future _currentTransaction = Future.sync(() => {});

  /// Blackholes any ongoing sync call. Currently ongoing sync *processing* is
  /// still going to be finished, new data is ignored.
  Future<void> abortSync() async {
    _aborted = true;
    backgroundSync = false;
    _currentSyncId = -1;
    try {
      await _currentTransaction;
    } catch (_) {
      // No-OP
    }
    _currentSync = null;
    // reset _aborted for being able to restart the sync.
    _aborted = false;
  }

  /// Stops the synchronization and closes the database. After this
  /// you can safely make this Client instance null.
  Future<void> dispose({bool closeDatabase = true}) async {
    _disposed = true;
    await abortSync();
    encryption?.dispose();
    encryption = null;
    try {
      if (closeDatabase && database != null) {
        await database
            .close()
            .catchError((e, s) => Logs().w('Failed to close database: ', e, s));
        _database = null;
      }
    } catch (error, stacktrace) {
      Logs().w('Failed to close database: ', error, stacktrace);
    }
    return;
  }
}

class SdkError {
  Exception exception;
  StackTrace stackTrace;

  SdkError({this.exception, this.stackTrace});
}

class BadServerVersionsException implements Exception {
  final Set<String> serverVersions, supportedVersions;
  BadServerVersionsException(this.serverVersions, this.supportedVersions);

  @override
  String toString() =>
      'Server supports the versions: ${serverVersions.toString()} but this application is only compatible with ${supportedVersions.toString()}.';
}

class BadServerLoginTypesException implements Exception {
  final Set<String> serverLoginTypes, supportedLoginTypes;
  BadServerLoginTypesException(this.serverLoginTypes, this.supportedLoginTypes);

  @override
  String toString() =>
      'Server supports the Login Types: ${serverLoginTypes.toString()} but this application is only compatible with ${supportedLoginTypes.toString()}.';
}
