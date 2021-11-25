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

import 'package:http/http.dart' as http;
import 'package:matrix/src/utils/run_in_root.dart';
import 'package:matrix/src/utils/sync_update_item_count.dart';
import 'package:mime/mime.dart';
import 'package:olm/olm.dart' as olm;
import 'package:collection/collection.dart' show IterableExtension;

import '../encryption.dart';
import '../matrix.dart';
import 'database/database_api.dart';
import 'event.dart';
import 'room.dart';
import 'user.dart';
import 'utils/commands_extension.dart';
import 'utils/device_keys_list.dart';
import 'utils/event_update.dart';
import 'utils/http_timeout.dart';
import 'utils/matrix_file.dart';
import 'utils/run_benchmarked.dart';
import 'utils/to_device_event.dart';
import 'utils/uia_request.dart';
import 'utils/multilock.dart';

typedef RoomSorter = int Function(Room a, Room b);

enum LoginState { loggedIn, loggedOut }

extension TrailingSlash on Uri {
  Uri stripTrailingSlash() => path.endsWith('/')
      ? replace(path: path.substring(0, path.length - 1))
      : this;
}

/// Represents a Matrix client to communicate with a
/// [Matrix](https://matrix.org) homeserver and is the entry point for this
/// SDK.
class Client extends MatrixApi {
  int? _id;

  // Keeps track of the currently ongoing syncRequest
  // in case we want to cancel it.
  int _currentSyncId = -1;

  int? get id => _id;

  final FutureOr<DatabaseApi> Function(Client)? databaseBuilder;
  final FutureOr<DatabaseApi> Function(Client)? legacyDatabaseBuilder;
  final FutureOr<void> Function(Client)? databaseDestroyer;
  final FutureOr<void> Function(Client)? legacyDatabaseDestroyer;
  DatabaseApi? _database;

  DatabaseApi? get database => _database;

  bool enableE2eeRecovery;

  @deprecated
  MatrixApi get api => this;

  Encryption? encryption;

  Set<KeyVerificationMethod> verificationMethods;

  Set<String> importantStateEvents;

  Set<String> roomPreviewLastEvents;

  Set<String> supportedLoginTypes;

  int sendMessageTimeoutSeconds;

  bool requestHistoryOnLimitedTimeline;

  bool formatLocalpart = true;

  bool mxidLocalPartFallback = true;

  // For CommandsClientExtension
  final Map<String, FutureOr<String?> Function(CommandArgs)> commands = {};
  final Filter syncFilter;

  String? syncFilterId;

  final Future<R> Function<Q, R>(FutureOr<R> Function(Q), Q,
      {String debugLabel})? compute;

  Future<T> runInBackground<T, U>(
      FutureOr<T> Function(U arg) function, U arg) async {
    final compute = this.compute;
    if (compute != null) {
      return await compute(function, arg);
    }
    return await function(arg);
  }

  /// Create a client
  /// [clientName] = unique identifier of this client
  /// [databaseBuilder]: A function that creates the database instance, that will be used.
  /// [legacyDatabaseBuilder]: Use this for your old database implementation to perform an automatic migration
  /// [databaseDestroyer]: A function that can be used to destroy a database instance, for example by deleting files from disk.
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
  /// Set [compute] to the Flutter compute method to enable the SDK to run some
  /// code in background.
  Client(
    this.clientName, {
    this.databaseBuilder,
    this.databaseDestroyer,
    this.legacyDatabaseBuilder,
    this.legacyDatabaseDestroyer,
    this.enableE2eeRecovery = false,
    Set<KeyVerificationMethod>? verificationMethods,
    http.Client? httpClient,
    Set<String>? importantStateEvents,
    Set<String>? roomPreviewLastEvents,
    this.pinUnreadRooms = false,
    this.pinInvitedRooms = true,
    this.sendMessageTimeoutSeconds = 60,
    this.requestHistoryOnLimitedTimeline = false,
    Set<String>? supportedLoginTypes,
    this.compute,
    Filter? syncFilter,
    @deprecated bool? debug,
  })  : syncFilter = syncFilter ??
            Filter(
              room: RoomFilter(
                state: StateFilter(lazyLoadMembers: true),
              ),
            ),
        importantStateEvents = importantStateEvents ??= {},
        roomPreviewLastEvents = roomPreviewLastEvents ??= {},
        supportedLoginTypes =
            supportedLoginTypes ?? {AuthenticationTypes.password},
        __loginState = LoginState.loggedOut,
        verificationMethods = verificationMethods ?? <KeyVerificationMethod>{},
        super(
            httpClient:
                VariableTimeoutHttpClient(httpClient ?? http.Client())) {
    importantStateEvents.addAll([
      EventTypes.RoomName,
      EventTypes.RoomAvatar,
      EventTypes.Message,
      EventTypes.Encrypted,
      EventTypes.Encryption,
      EventTypes.RoomCanonicalAlias,
      EventTypes.RoomTombstone,
      EventTypes.spaceChild,
      EventTypes.spaceParent,
      EventTypes.RoomCreate,
    ]);
    roomPreviewLastEvents.addAll([
      EventTypes.Message,
      EventTypes.Encrypted,
      EventTypes.Sticker,
    ]);

    // register all the default commands
    registerDefaultCommands();
  }

  /// The required name for this client.
  final String clientName;

  /// The Matrix ID of the current logged user.
  String? get userID => _userID;
  String? _userID;

  /// This points to the position in the synchronization history.
  String? prevBatch;

  /// The device ID is an unique identifier for this device.
  String? get deviceID => _deviceID;
  String? _deviceID;

  /// The device name is a human readable identifier for this device.
  String? get deviceName => _deviceName;
  String? _deviceName;

  /// Returns the current login state.
  LoginState get loginState => __loginState;
  LoginState __loginState;
  set _loginState(LoginState state) {
    __loginState = state;
    onLoginStateChanged.add(state);
  }

  bool isLogged() => accessToken != null;

  /// A list of all rooms the user is participating or invited.
  List<Room> get rooms => _rooms;
  List<Room> _rooms = [];

  /// Whether this client supports end-to-end encryption using olm.
  bool get encryptionEnabled => encryption?.enabled == true;

  /// Whether this client is able to encrypt and decrypt files.
  bool get fileEncryptionEnabled => encryptionEnabled && true;

  String get identityKey => encryption?.identityKey ?? '';

  String get fingerprintKey => encryption?.fingerprintKey ?? '';

  /// Wheather this session is unknown to others
  bool get isUnknownSession =>
      userDeviceKeys[userID]?.deviceKeys[deviceID]?.signed != true;

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

  Room? getRoomByAlias(String alias) {
    for (final room in rooms) {
      if (room.canonicalAlias == alias) return room;
    }
    return null;
  }

  /// Searches in the local cache for the given room and returns null if not
  /// found. If you have loaded the [loadArchive()] before, it can also return
  /// archived rooms.
  Room? getRoomById(String id) {
    for (final room in <Room>[...rooms, ..._archivedRooms]) {
      if (room.id == id) return room;
    }

    return null;
  }

  Map<String, dynamic> get directChats =>
      accountData['m.direct']?.content ?? {};

  /// Returns the (first) room ID from the store which is a private chat with the user [userId].
  /// Returns null if there is none.
  String? getDirectChatFromUserId(String userId) {
    final directChats = accountData['m.direct']?.content[userId];
    if (directChats is List<dynamic> && directChats.isNotEmpty) {
      final potentialRooms = directChats
          .cast<String>()
          .map(getRoomById)
          .where((room) => room != null && room.membership == Membership.join);
      if (potentialRooms.isNotEmpty) {
        return potentialRooms.fold<Room>(potentialRooms.first!,
            (Room prev, Room? r) {
          if (r == null) {
            return prev;
          }
          final prevLast =
              prev.lastEvent?.originServerTs.millisecondsSinceEpoch ?? 0;
          final rLast = r.lastEvent?.originServerTs.millisecondsSinceEpoch ?? 0;

          return rLast > prevLast ? r : prev;
        }).id;
      }
    }
    for (final room in rooms) {
      if (room.membership == Membership.invite &&
          room.getState(EventTypes.RoomMember, userID!)?.senderId == userId &&
          room.getState(EventTypes.RoomMember, userID!)?.content['is_direct'] ==
              true) {
        return room.id;
      }
    }
    return null;
  }

  /// Gets discovery information about the domain. The file may include additional keys.
  Future<DiscoveryInformation> getDiscoveryInformationsByUserId(
    String MatrixIdOrDomain,
  ) async {
    try {
      final response = await http.get(Uri.https(
          MatrixIdOrDomain.domain ?? '', '/.well-known/matrix/client'));
      var respBody = response.body;
      try {
        respBody = utf8.decode(response.bodyBytes);
      } catch (_) {
        // No-OP
      }
      final rawJson = json.decode(respBody);
      return DiscoveryInformation.fromJson(rawJson);
    } catch (_) {
      // we got an error processing or fetching the well-known information, let's
      // provide a reasonable fallback.
      return DiscoveryInformation(
        mHomeserver: HomeserverInformation(
            baseUrl: Uri.https(MatrixIdOrDomain.domain ?? '', '')),
      );
    }
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
  Future<DiscoveryInformation?> checkHomeserver(dynamic homeserverUrl,
      {bool checkWellKnown = true}) async {
    try {
      var homeserver = this.homeserver =
          (homeserverUrl is Uri) ? homeserverUrl : Uri.parse(homeserverUrl);
      homeserver = this.homeserver = homeserver.stripTrailingSlash();

      // Look up well known
      DiscoveryInformation? wellKnown;
      if (checkWellKnown) {
        try {
          wellKnown = await getWellknown();
          homeserver = this.homeserver =
              wellKnown.mHomeserver.baseUrl.stripTrailingSlash();
        } catch (e) {
          Logs().v('Found no well known information', e);
        }
      }

      // Check if server supports at least one supported version
      final versions = await getVersions();
      if (!versions.versions
          .any((version) => supportedVersions.contains(version))) {
        throw BadServerVersionsException(
            versions.versions.toSet(), supportedVersions);
      }

      final loginTypes = await getLoginFlows() ?? [];
      if (!loginTypes.any((f) => supportedLoginTypes.contains(f.type))) {
        throw BadServerLoginTypesException(
            loginTypes.map((f) => f.type ?? '').toSet(), supportedLoginTypes);
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
  Future<RegisterResponse> register({
    String? username,
    String? password,
    String? deviceId,
    String? initialDeviceDisplayName,
    bool? inhibitLogin,
    AuthenticationData? auth,
    AccountKind? kind,
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
    final accessToken = response.accessToken;
    final deviceId_ = response.deviceId;
    final userId = response.userId;
    final homeserver = this.homeserver;
    if (accessToken == null || deviceId_ == null || homeserver == null) {
      throw Exception(
          'Registered but token, device ID, user ID or homeserver is null.');
    }
    await init(
        newToken: accessToken,
        newUserID: userId,
        newHomeserver: homeserver,
        newDeviceName: initialDeviceDisplayName ?? '',
        newDeviceID: deviceId_);
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
  Future<LoginResponse> login(
    LoginType type, {
    AuthenticationIdentifier? identifier,
    String? password,
    String? token,
    String? deviceId,
    String? initialDeviceDisplayName,
    AuthenticationData? auth,
    @Deprecated('Deprecated in favour of identifier.') String? user,
    @Deprecated('Deprecated in favour of identifier.') String? medium,
    @Deprecated('Deprecated in favour of identifier.') String? address,
  }) async {
    if (homeserver == null && user != null && user.isValidMatrixId) {
      await checkHomeserver(user.domain);
    }
    final response = await super.login(
      type,
      identifier: identifier,
      password: password,
      token: token,
      deviceId: deviceId,
      initialDeviceDisplayName: initialDeviceDisplayName,
      // ignore: deprecated_member_use
      user: user,
      // ignore: deprecated_member_use
      medium: medium,
      // ignore: deprecated_member_use
      address: address,
    );

    // Connect if there is an access token in the response.
    final accessToken = response.accessToken;
    final deviceId_ = response.deviceId;
    final userId = response.userId;
    final homeserver_ = homeserver;
    if (accessToken == null ||
        deviceId_ == null ||
        userId == null ||
        homeserver_ == null) {
      throw Exception('Registered but token, device ID or user ID is null.');
    }
    await init(
      newToken: accessToken,
      newUserID: userId,
      newHomeserver: homeserver_,
      newDeviceName: initialDeviceDisplayName ?? '',
      newDeviceID: deviceId_,
    );
    return response;
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
      await clear();
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
      await clear();
    }
  }

  /// Run any request and react on user interactive authentication flows here.
  Future<T> uiaRequestBackground<T>(
      Future<T> Function(AuthenticationData? auth) request) {
    final completer = Completer<T>();
    UiaRequest? uia;
    uia = UiaRequest(
      request: request,
      onUpdate: (state) {
        if (uia != null) {
          if (state == UiaRequestState.done) {
            completer.complete(uia.result);
          } else if (state == UiaRequestState.fail) {
            completer.completeError(uia.error!);
          } else {
            onUiaRequest.add(uia);
          }
        }
      },
    );
    return completer.future;
  }

  /// Returns an existing direct room ID with this user or creates a new one.
  /// By default encryption will be enabled if the client supports encryption
  /// and the other user has uploaded any encryption keys.
  Future<String> startDirectChat(
    String mxid, {
    bool? enableEncryption,
    List<StateEvent>? initialState,
    bool waitForSync = true,
  }) async {
    // Try to find an existing direct chat
    final directChatRoomId = getDirectChatFromUserId(mxid);
    if (directChatRoomId != null) return directChatRoomId;

    enableEncryption ??=
        encryptionEnabled && await userOwnsEncryptionKeys(mxid);
    if (enableEncryption) {
      initialState ??= [];
      if (!initialState.any((s) => s.type == EventTypes.Encryption)) {
        initialState.add(StateEvent(
          content: {
            'algorithm': supportedGroupEncryptionAlgorithms.first,
          },
          type: EventTypes.Encryption,
        ));
      }
    }

    // Start a new direct chat
    final roomId = await createRoom(
      invite: [mxid],
      isDirect: true,
      preset: CreateRoomPreset.trustedPrivateChat,
      initialState: initialState,
    );

    if (waitForSync && getRoomById(roomId) == null) {
      // Wait for room actually appears in sync
      await onSync.stream
          .firstWhere((sync) => sync.rooms?.join?.containsKey(roomId) ?? false);
    }

    await Room(id: roomId, client: this).addToDirectChat(mxid);

    return roomId;
  }

  /// Simplified method to create a new group chat. By default it is a private
  /// chat. The encryption is enabled if this client supports encryption and
  /// the preset is not a public chat.
  Future<String> createGroupChat({
    String? groupName,
    bool? enableEncryption,
    List<String>? invite,
    CreateRoomPreset preset = CreateRoomPreset.privateChat,
    List<StateEvent>? initialState,
    Visibility? visibility,
    bool waitForSync = true,
  }) async {
    enableEncryption ??=
        encryptionEnabled && preset != CreateRoomPreset.publicChat;
    if (enableEncryption) {
      initialState ??= [];
      if (!initialState.any((s) => s.type == EventTypes.Encryption)) {
        initialState.add(StateEvent(
          content: {
            'algorithm': supportedGroupEncryptionAlgorithms.first,
          },
          type: EventTypes.Encryption,
        ));
      }
    }
    final roomId = await createRoom(
      invite: invite,
      preset: preset,
      name: groupName,
      initialState: initialState,
      visibility: visibility,
    );

    if (waitForSync) {
      if (getRoomById(roomId) == null) {
        // Wait for room actually appears in sync
        await onSync.stream.firstWhere(
            (sync) => sync.rooms?.join?.containsKey(roomId) ?? false);
      }
    }
    return roomId;
  }

  /// Checks if the given user has encryption keys. May query keys from the
  /// server to answer this.
  Future<bool> userOwnsEncryptionKeys(String userId) async {
    if (userId == userID) return encryptionEnabled;
    if (_userDeviceKeys.containsKey(userId)) {
      return true;
    }
    final keys = await queryKeys({userId: []});
    return keys.deviceKeys?.isNotEmpty ?? false;
  }

  /// Creates a new space and returns the Room ID. The parameters are mostly
  /// the same like in [createRoom()].
  /// Be aware that spaces appear in the [rooms] list. You should check if a
  /// room is a space by using the `room.isSpace` getter and then just use the
  /// room as a space with `room.toSpace()`.
  ///
  /// https://github.com/matrix-org/matrix-doc/blob/matthew/msc1772/proposals/1772-groups-as-rooms.md
  Future<String> createSpace({
    String? name,
    String? topic,
    Visibility visibility = Visibility.public,
    String? spaceAliasName,
    List<String>? invite,
    List<Invite3pid>? invite3pid,
    String? roomVersion,
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
      final profileSet = <Profile>{};
      for (final room in rooms) {
        final user = room.getUserByMXIDSync(userID!);
        profileSet.add(Profile(
          avatarUrl: user.avatarUrl,
          displayName: user.displayName,
          userId: user.id,
        ));
      }
      if (profileSet.length == 1) return profileSet.single;
    }
    return getProfileFromUserId(userID!);
  }

  final Map<String, ProfileInformation> _profileCache = {};

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
      final room = rooms.firstWhereOrNull((Room room) =>
          room.getParticipants().indexWhere((User user) => user.id == userId) !=
          -1);
      if (room != null) {
        final user =
            room.getParticipants().firstWhere((User user) => user.id == userId);
        return Profile(
            userId: userId,
            displayName: user.displayName,
            avatarUrl: user.avatarUrl);
      }
    }

    var profile = _profileCache[userId];
    if (cache && profile != null) {
      return Profile(
          userId: userId,
          displayName: profile.displayname,
          avatarUrl: profile.avatarUrl);
    }
    profile = await getUserProfile(userId);
    _profileCache[userId] = profile;
    return Profile(
        userId: userId,
        displayName: profile.displayname,
        avatarUrl: profile.avatarUrl);
  }

  final List<Room> _archivedRooms = [];

  @Deprecated('Use [loadArchive()] instead.')
  Future<List<Room>> get archive => loadArchive();

  Future<List<Room>> loadArchive() async {
    _archivedRooms.clear();
    final syncResp = await sync(
      filter: '{"room":{"include_leave":true,"timeline":{"limit":10}}}',
      timeout: 0,
    );

    final leave = syncResp.rooms?.leave;
    if (leave != null) {
      for (final entry in leave.entries) {
        final id = entry.key;
        final room = entry.value;
        final leftRoom = Room(
          id: id,
          membership: Membership.leave,
          client: this,
          roomAccountData:
              room.accountData?.asMap().map((k, v) => MapEntry(v.type, v)) ??
                  <String, BasicRoomEvent>{},
        );

        room.timeline?.events?.forEach((event) {
          leftRoom.setState(Event.fromMatrixEvent(
            event,
            leftRoom,
          ));
        });
        leftRoom.prev_batch = room.timeline?.prevBatch;
        room.state?.forEach((event) {
          leftRoom.setState(Event.fromMatrixEvent(
            event,
            leftRoom,
          ));
        });
        _archivedRooms.add(leftRoom);
      }
    }
    return _archivedRooms;
  }

  /// Uploads a file and automatically caches it in the database, if it is small enough
  /// and returns the mxc url.
  @override
  Future<Uri> uploadContent(Uint8List file,
      {String? filename, String? contentType}) async {
    contentType ??= lookupMimeType(filename ?? '', headerBytes: file);
    final mxc = await super
        .uploadContent(file, filename: filename, contentType: contentType);

    final database = this.database;
    if (database != null && file.length <= database.maxFileSize) {
      await database.storeFile(
          mxc, file, DateTime.now().millisecondsSinceEpoch);
    }
    return mxc;
  }

  /// Sends a typing notification and initiates a megolm session, if needed
  @override
  Future<void> setTyping(
    String userId,
    String roomId,
    bool typing, {
    int? timeout,
  }) async {
    await super.setTyping(userId, roomId, typing, timeout: timeout);
    final room = getRoomById(roomId);
    if (typing && room != null && encryptionEnabled && room.encrypted) {
      // ignore: unawaited_futures
      encryption?.keyManager.prepareOutboundGroupSession(roomId);
    }
  }

  /// Uploads a new user avatar for this user. Leave file null to remove the
  /// current avatar.
  Future<void> setAvatar(MatrixFile? file) async {
    if (file == null) {
      // We send an empty String to remove the avatar. Sending Null **should**
      // work but it doesn't with Synapse. See:
      // https://gitlab.com/famedly/company/frontend/famedlysdk/-/issues/254
      return setAvatarUrl(userID!, Uri.parse(''));
    }
    final uploadResp = await uploadContent(
      file.bytes,
      filename: file.name,
      contentType: file.mimeType,
    );
    await setAvatarUrl(userID!, uploadResp);
    return;
  }

  /// Returns the global push rules for the logged in user.
  PushRuleSet? get globalPushRules {
    final pushrules = accountData['m.push_rules']?.content['global'];
    return pushrules != null ? PushRuleSet.fromJson(pushrules) : null;
  }

  /// Returns the device push rules for the logged in user.
  PushRuleSet? get devicePushRules {
    final pushrules = accountData['m.push_rules']?.content['device'];
    return pushrules != null ? PushRuleSet.fromJson(pushrules) : null;
  }

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

  /// The onToDeviceEvent is called when there comes a new to device event. It is
  /// already decrypted if necessary.
  final StreamController<ToDeviceEvent> onToDeviceEvent =
      StreamController.broadcast();

  /// Called when the login state e.g. user gets logged out.
  final StreamController<LoginState> onLoginStateChanged =
      StreamController.broadcast();

  /// Called when the local cache is reset
  final StreamController<bool> onCacheCleared = StreamController.broadcast();

  /// Encryption errors are coming here.
  final StreamController<SdkError> onEncryptionError =
      StreamController.broadcast();

  /// This is called once, when the first sync has been processed.
  final StreamController<bool> onFirstSync = StreamController.broadcast();

  /// When a new sync response is coming in, this gives the complete payload.
  final StreamController<SyncUpdate> onSync = StreamController.broadcast();

  /// This gives the current status of the synchronization
  final StreamController<SyncStatusUpdate> onSyncStatus =
      StreamController.broadcast();

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

  /// Will be called on call replaces.
  final StreamController<Event> onCallReplaces = StreamController.broadcast();

  /// Will be called on select answers.
  final StreamController<Event> onCallSelectAnswer =
      StreamController.broadcast();

  /// Will be called on rejects.
  final StreamController<Event> onCallReject = StreamController.broadcast();

  /// Will be called on negotiates.
  final StreamController<Event> onCallNegotiate = StreamController.broadcast();

  /// Will be called on Asserted Identity received.
  final StreamController<Event> onAssertedIdentityReceived =
      StreamController.broadcast();

  /// Will be called on SDPStream Metadata changed.
  final StreamController<Event> onSDPStreamMetadataChangedReceived =
      StreamController.broadcast();

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
    String? newToken,
    Uri? newHomeserver,
    String? newUserID,
    String? newDeviceName,
    String? newDeviceID,
    String? newOlmAccount,
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
  /// Usually you don't need to call this method yourself because [login()], [register()]
  /// and even the constructor calls it.
  ///
  /// Sends [LoginState.loggedIn] to [onLoginStateChanged].
  ///
  /// If one of [newToken], [newUserID], [newDeviceID], [newDeviceName] is set then
  /// all of them must be set! If you don't set them, this method will try to
  /// get them from the database.
  ///
  /// Set [waitForFirstSync] and [waitUntilLoadCompletedLoaded] to false to speed this
  /// up. You can then wait for `roomsLoading`, `accountDataLoading` and
  /// `userDeviceKeysLoading` where it is necessary.
  Future<void> init({
    String? newToken,
    Uri? newHomeserver,
    String? newUserID,
    String? newDeviceName,
    String? newDeviceID,
    String? newOlmAccount,
    bool waitForFirstSync = true,
    bool waitUntilLoadCompletedLoaded = true,
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

      final databaseBuilder = this.databaseBuilder;
      if (databaseBuilder != null) {
        _database ??= await runBenchmarked<DatabaseApi>(
          'Build database',
          () async => await databaseBuilder(this),
        );
      }

      String? olmAccount;
      String? accessToken;
      String? _userID;
      final account = await this.database?.getClient(clientName);
      if (account != null) {
        _id = account['client_id'];
        homeserver = Uri.parse(account['homeserver_url']);
        accessToken = this.accessToken = account['token'];
        _userID = this._userID = account['user_id'];
        _deviceID = account['device_id'];
        _deviceName = account['device_name'];
        syncFilterId = account['sync_filter_id'];
        prevBatch = account['prev_batch'];
        olmAccount = account['olm_account'];
      }
      if (newToken != null) {
        accessToken = this.accessToken = newToken;
        homeserver = newHomeserver;
        _userID = this._userID = newUserID;
        _deviceID = newDeviceID;
        _deviceName = newDeviceName;
        olmAccount = newOlmAccount;
      } else {
        accessToken = this.accessToken = newToken ?? accessToken;
        homeserver = newHomeserver ?? homeserver;
        _userID = this._userID = newUserID ?? _userID;
        _deviceID = newDeviceID ?? _deviceID;
        _deviceName = newDeviceName ?? _deviceName;
        olmAccount = newOlmAccount ?? olmAccount;
      }

      if (accessToken == null || homeserver == null || _userID == null) {
        if (legacyDatabaseBuilder != null) {
          await _migrateFromLegacyDatabase();
          if (isLogged()) return;
        }
        // we aren't logged in
        encryption?.dispose();
        encryption = null;
        _loginState = LoginState.loggedOut;
        Logs().i('User is not logged in.');
        _initLock = false;
        return;
      }

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

      final database = this.database;
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
        userDeviceKeysLoading = database
            .getUserDeviceKeys(this)
            .then((keys) => _userDeviceKeys = keys);
        roomsLoading = database.getRoomList(this).then((rooms) {
          _rooms = rooms;
          _sortRooms();
        });
        _sortRooms();
        accountDataLoading =
            database.getAccountData().then((data) => accountData = data);
        presences.clear();
        if (waitUntilLoadCompletedLoaded) {
          await userDeviceKeysLoading;
          await roomsLoading;
          await accountDataLoading;
        }
      }
      _initLock = false;
      _loginState = LoginState.loggedIn;
      Logs().i(
        'Successfully connected as ${userID?.localpart} with ${homeserver.toString()}',
      );

      final syncFuture = _sync();
      if (waitForFirstSync) {
        await syncFuture;
      }
      return;
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
  Future<void> clear() async {
    Logs().outputEvents.clear();
    try {
      await abortSync();
      await database?.clear();
      _backgroundSync = true;
    } catch (e, s) {
      Logs().e('Unable to clear database', e, s);
    } finally {
      _database = null;
    }

    _id = accessToken = syncFilterId =
        homeserver = _userID = _deviceID = _deviceName = prevBatch = null;
    _rooms = [];
    encryption?.dispose();
    encryption = null;
    final databaseDestroyer = this.databaseDestroyer;
    if (databaseDestroyer != null) {
      try {
        await database?.close();
      } catch (e, s) {
        Logs().e('Unable to close database', e, s);
      }
      await databaseDestroyer(this);
      _database = null;
    }
    _loginState = LoginState.loggedOut;
  }

  bool _backgroundSync = true;
  Future<void>? _currentSync;
  Future<void> _retryDelay = Future.value();

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

  Future<void> _sync() async {
    if (_currentSync == null) {
      final _currentSync = this._currentSync = _innerSync();
      // ignore: unawaited_futures
      _currentSync.whenComplete(() {
        this._currentSync = null;
        if (_backgroundSync && isLogged() && !_disposed) {
          _sync();
        }
      });
    }
    await _currentSync;
  }

  /// Presence that is set on sync.
  PresenceType? syncPresence;

  Future<void> _checkSyncFilter() async {
    final userID = this.userID;
    if (syncFilterId == null && userID != null) {
      final syncFilterId =
          this.syncFilterId = await defineFilter(userID, syncFilter);
      await database?.storeSyncFilterId(syncFilterId);
    }
    return;
  }

  Future<void> _innerSync() async {
    await _retryDelay;
    _retryDelay = Future.delayed(Duration(seconds: syncErrorTimeoutSec));
    if (!isLogged() || _disposed || _aborted) return null;
    try {
      if (_initLock) {
        Logs().d('Running sync while init isn\'t done yet, dropping request');
        return;
      }
      var syncError;
      await _checkSyncFilter();
      final syncRequest = sync(
        filter: syncFilterId,
        since: prevBatch,
        timeout: prevBatch != null ? 30000 : null,
        setPresence: syncPresence,
      ).then((v) => Future<SyncUpdate?>.value(v)).catchError((e) {
        syncError = e;
        return null;
      });
      _currentSyncId = syncRequest.hashCode;
      onSyncStatus.add(SyncStatusUpdate(SyncStatus.waitingForResponse));
      final syncResp = await syncRequest;
      onSyncStatus.add(SyncStatusUpdate(SyncStatus.processing));
      if (syncResp == null) throw syncError ?? 'Unknown sync error';
      if (_currentSyncId != syncRequest.hashCode) {
        Logs()
            .w('Current sync request ID has changed. Dropping this sync loop!');
        return;
      }

      final database = this.database;
      if (database != null) {
        await userDeviceKeysLoading;
        await roomsLoading;
        await accountDataLoading;
        _currentTransaction = database.transaction(() async {
          await _handleSync(syncResp);
          if (prevBatch != syncResp.nextBatch) {
            await database.storePrevBatch(syncResp.nextBatch);
          }
        });
        await runBenchmarked(
          'Process sync',
          () async => await _currentTransaction,
          syncResp.itemCount,
        );
        onSyncStatus.add(SyncStatusUpdate(SyncStatus.cleaningUp));
      } else {
        await _handleSync(syncResp);
      }
      if (_disposed || _aborted) return;
      if (prevBatch == null) {
        onFirstSync.add(true);
        prevBatch = syncResp.nextBatch;
        _sortRooms();
      }
      prevBatch = syncResp.nextBatch;
      // ignore: unawaited_futures
      database?.deleteOldFiles(
          DateTime.now().subtract(Duration(days: 30)).millisecondsSinceEpoch);
      await updateUserDeviceKeys();
      if (encryptionEnabled) {
        encryption?.onSync();
      }

      // try to process the to_device queue
      try {
        await processToDeviceQueue();
      } catch (_) {} // we want to dispose any errors this throws

      _retryDelay = Future.value();
      onSyncStatus.add(SyncStatusUpdate(SyncStatus.finished));
    } on MatrixException catch (e, s) {
      onSyncStatus.add(SyncStatusUpdate(SyncStatus.error,
          error: SdkError(exception: e, stackTrace: s)));
      if (e.error == MatrixError.M_UNKNOWN_TOKEN) {
        Logs().w('The user has been logged out!');
        await clear();
      }
    } on MatrixConnectionException catch (e, s) {
      Logs().w('Synchronization connection failed');
      onSyncStatus.add(SyncStatusUpdate(SyncStatus.error,
          error: SdkError(exception: e, stackTrace: s)));
    } catch (e, s) {
      if (!isLogged() || _disposed || _aborted) return;
      Logs().e('Error during processing events', e, s);
      onSyncStatus.add(SyncStatusUpdate(SyncStatus.error,
          error: SdkError(
              exception: e is Exception ? e : Exception(e), stackTrace: s)));
    }
  }

  /// Use this method only for testing utilities!
  Future<void> handleSync(SyncUpdate sync, {bool sortAtTheEnd = false}) async {
    // ensure we don't upload keys because someone forgot to set a key count
    sync.deviceOneTimeKeysCount ??= {'signed_curve25519': 100};
    await _handleSync(sync, sortAtTheEnd: sortAtTheEnd);
  }

  Future<void> _handleSync(SyncUpdate sync, {bool sortAtTheEnd = false}) async {
    final syncToDevice = sync.toDevice;
    if (syncToDevice != null) {
      await _handleToDeviceEvents(syncToDevice);
    }

    if (sync.rooms != null) {
      final join = sync.rooms?.join;
      if (join != null) {
        await _handleRooms(join, sortAtTheEnd: sortAtTheEnd);
      }
      final invite = sync.rooms?.invite;
      if (invite != null) {
        await _handleRooms(invite, sortAtTheEnd: sortAtTheEnd);
      }
      final leave = sync.rooms?.leave;
      if (leave != null) {
        await _handleRooms(leave, sortAtTheEnd: sortAtTheEnd);
      }
      _sortRooms();
    }
    for (final newPresence in sync.presence ?? []) {
      presences[newPresence.senderId] = newPresence;
      onPresence.add(newPresence);
    }
    for (final newAccountData in sync.accountData ?? []) {
      await database?.storeAccountData(
        newAccountData.type,
        jsonEncode(newAccountData.content),
      );
      accountData[newAccountData.type] = newAccountData;
      onAccountData.add(newAccountData);
    }

    final syncDeviceLists = sync.deviceLists;
    if (syncDeviceLists != null) {
      await _handleDeviceListsEvents(syncDeviceLists);
    }
    if (encryptionEnabled) {
      encryption?.handleDeviceOneTimeKeysCount(
          sync.deviceOneTimeKeysCount, sync.deviceUnusedFallbackKeyTypes);
    }
    onSync.add(sync);
  }

  Future<void> _handleDeviceListsEvents(DeviceListsUpdate deviceLists) async {
    if (deviceLists.changed is List) {
      for (final userId in deviceLists.changed ?? []) {
        final userKeys = _userDeviceKeys[userId];
        if (userKeys != null) {
          userKeys.outdated = true;
          await database?.storeUserDeviceKeysInfo(userId, true);
        }
      }
      for (final userId in deviceLists.left ?? []) {
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
        toDeviceEvent = await encryption!.decryptToDeviceEvent(toDeviceEvent);
        Logs().v('Decrypted type is: ${toDeviceEvent.type}');
      }
      if (encryptionEnabled) {
        await encryption?.handleToDeviceEvent(toDeviceEvent);
      }
      onToDeviceEvent.add(toDeviceEvent);
    }
  }

  Future<void> _handleRooms(Map<String, SyncRoomUpdate> rooms,
      {bool sortAtTheEnd = false}) async {
    var handledRooms = 0;
    for (final entry in rooms.entries) {
      onSyncStatus.add(SyncStatusUpdate(
        SyncStatus.processing,
        progress: ++handledRooms / rooms.length,
      ));
      final id = entry.key;
      final room = entry.value;

      await database?.storeRoomUpdate(id, room, this);
      _updateRoomsByRoomUpdate(id, room);

      /// Handle now all room events and save them in the database
      if (room is JoinedRoomUpdate) {
        final state = room.state;
        if (state != null && state.isNotEmpty) {
          // TODO: This method seems to be comperatively slow for some updates
          await _handleRoomEvents(
              id, state.map((i) => i.toJson()).toList(), EventUpdateType.state,
              sortAtTheEnd: sortAtTheEnd);
        }

        final timelineEvents = room.timeline?.events;
        if (timelineEvents != null && timelineEvents.isNotEmpty) {
          await _handleRoomEvents(
              id,
              timelineEvents.map((i) => i.toJson()).toList(),
              sortAtTheEnd ? EventUpdateType.history : EventUpdateType.timeline,
              sortAtTheEnd: sortAtTheEnd);
        }

        final ephemeral = room.ephemeral;
        if (ephemeral != null && ephemeral.isNotEmpty) {
          // TODO: This method seems to be comperatively slow for some updates
          await _handleEphemerals(
              id, ephemeral.map((i) => i.toJson()).toList());
        }

        final accountData = room.accountData;
        if (accountData != null && accountData.isNotEmpty) {
          await _handleRoomEvents(
              id,
              accountData.map((i) => i.toJson()).toList(),
              EventUpdateType.accountData);
        }
      }

      if (room is LeftRoomUpdate) {
        final timelineEvents = room.timeline?.events;
        if (timelineEvents != null && timelineEvents.isNotEmpty) {
          await _handleRoomEvents(
              id,
              timelineEvents.map((i) => i.toJson()).toList(),
              EventUpdateType.timeline,
              sortAtTheEnd: sortAtTheEnd);
        }
        final accountData = room.accountData;
        if (accountData != null && accountData.isNotEmpty) {
          await _handleRoomEvents(
              id,
              accountData.map((i) => i.toJson()).toList(),
              EventUpdateType.accountData);
        }
        final state = room.state;
        if (state != null && state.isNotEmpty) {
          await _handleRoomEvents(
              id, state.map((i) => i.toJson()).toList(), EventUpdateType.state);
        }
      }

      if (room is InvitedRoomUpdate) {
        final state = room.inviteState;
        if (state != null && state.isNotEmpty) {
          await _handleRoomEvents(id, state.map((i) => i.toJson()).toList(),
              EventUpdateType.inviteState);
        }
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
        room ??= Room(id: id, client: this);

        final receiptStateContent =
            room.roomAccountData['m.receipt']?.content ?? {};
        for (final eventEntry in event['content'].entries) {
          final String eventID = eventEntry.key;
          if (event['content'][eventID]['m.read'] != null) {
            final Map<String, dynamic> userTimestampMap =
                event['content'][eventID]['m.read'];
            for (final userTimestampMapEntry in userTimestampMap.entries) {
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

      var update = EventUpdate(
        roomID: roomID,
        type: type,
        content: event,
      );
      if (event['type'] == EventTypes.Encrypted && encryptionEnabled) {
        update = await update.decrypt(room);
      }
      if (event['type'] == EventTypes.Message &&
          !room.isDirectChat &&
          database != null &&
          room.getState(EventTypes.RoomMember, event['sender']) == null) {
        // In order to correctly render room list previews we need to fetch the member from the database
        final user = await database?.getUser(event['sender'], room);
        if (user != null) {
          room.setState(user);
        }
      }
      _updateRoomsByEventUpdate(update);
      if (type != EventUpdateType.ephemeral) {
        await database?.storeEventUpdate(update, this);
      }
      if (encryptionEnabled) {
        await encryption?.handleEventUpdate(update);
      }
      onEvent.add(update);

      final rawUnencryptedEvent = update.content;

      if (prevBatch != null && type == EventUpdateType.timeline) {
        if (rawUnencryptedEvent['type'] == EventTypes.CallInvite) {
          onCallInvite.add(Event.fromJson(rawUnencryptedEvent, room));
        } else if (rawUnencryptedEvent['type'] == EventTypes.CallHangup) {
          onCallHangup.add(Event.fromJson(rawUnencryptedEvent, room));
        } else if (rawUnencryptedEvent['type'] == EventTypes.CallAnswer) {
          onCallAnswer.add(Event.fromJson(rawUnencryptedEvent, room));
        } else if (rawUnencryptedEvent['type'] == EventTypes.CallCandidates) {
          onCallCandidates.add(Event.fromJson(rawUnencryptedEvent, room));
        } else if (rawUnencryptedEvent['type'] == EventTypes.CallSelectAnswer) {
          onCallSelectAnswer.add(Event.fromJson(rawUnencryptedEvent, room));
        } else if (rawUnencryptedEvent['type'] == EventTypes.CallReject) {
          onCallReject.add(Event.fromJson(rawUnencryptedEvent, room));
        } else if (rawUnencryptedEvent['type'] == EventTypes.CallNegotiate) {
          onCallNegotiate.add(Event.fromJson(rawUnencryptedEvent, room));
        } else if (rawUnencryptedEvent['type'] == EventTypes.CallReplaces) {
          onCallReplaces.add(Event.fromJson(rawUnencryptedEvent, room));
        } else if (rawUnencryptedEvent['type'] ==
                EventTypes.CallAssertedIdentity ||
            rawUnencryptedEvent['type'] ==
                EventTypes.CallAssertedIdentityPrefix) {
          onAssertedIdentityReceived
              .add(Event.fromJson(rawUnencryptedEvent, room));
        } else if (rawUnencryptedEvent['type'] ==
                EventTypes.CallSDPStreamMetadataChanged ||
            rawUnencryptedEvent['type'] ==
                EventTypes.CallSDPStreamMetadataChangedPrefix) {
          onSDPStreamMetadataChangedReceived
              .add(Event.fromJson(rawUnencryptedEvent, room));
        }
      }
    }
  }

  void _updateRoomsByRoomUpdate(String roomId, SyncRoomUpdate chatUpdate) {
    // Update the chat list item.
    // Search the room in the rooms
    final roomIndex = rooms.indexWhere((r) => r.id == roomId);
    final found = roomIndex != -1;
    final membership = chatUpdate is LeftRoomUpdate
        ? Membership.leave
        : chatUpdate is InvitedRoomUpdate
            ? Membership.invite
            : Membership.join;

    // Does the chat already exist in the list rooms?
    if (!found && membership != Membership.leave) {
      final position = membership == Membership.invite ? 0 : rooms.length;
      // Add the new chat to the list
      final newRoom = chatUpdate is JoinedRoomUpdate
          ? Room(
              id: roomId,
              membership: membership,
              prev_batch: chatUpdate.timeline?.prevBatch,
              highlightCount:
                  chatUpdate.unreadNotifications?.highlightCount ?? 0,
              notificationCount:
                  chatUpdate.unreadNotifications?.notificationCount ?? 0,
              summary: chatUpdate.summary,
              client: this,
            )
          : Room(id: roomId, membership: membership, client: this);
      rooms.insert(position, newRoom);
    }
    // If the membership is "leave" then remove the item and stop here
    else if (found && membership == Membership.leave) {
      rooms.removeAt(roomIndex);
    }
    // Update notification, highlight count and/or additional informations
    else if (found &&
        chatUpdate is JoinedRoomUpdate &&
        (rooms[roomIndex].membership != membership ||
            rooms[roomIndex].notificationCount !=
                (chatUpdate.unreadNotifications?.notificationCount ?? 0) ||
            rooms[roomIndex].highlightCount !=
                (chatUpdate.unreadNotifications?.highlightCount ?? 0) ||
            chatUpdate.summary != null ||
            chatUpdate.timeline?.prevBatch != null)) {
      rooms[roomIndex].membership = membership;
      rooms[roomIndex].notificationCount =
          chatUpdate.unreadNotifications?.notificationCount ?? 0;
      rooms[roomIndex].highlightCount =
          chatUpdate.unreadNotifications?.highlightCount ?? 0;
      if (chatUpdate.timeline?.prevBatch != null) {
        rooms[roomIndex].prev_batch = chatUpdate.timeline?.prevBatch;
      }

      final summary = chatUpdate.summary;
      if (summary != null) {
        final roomSummaryJson = rooms[roomIndex].summary.toJson()
          ..addAll(summary.toJson());
        rooms[roomIndex].summary = RoomSummary.fromJson(roomSummaryJson);
      }
      rooms[roomIndex].onUpdate.add(rooms[roomIndex].id);
      if ((chatUpdate.timeline?.limited ?? false) &&
          requestHistoryOnLimitedTimeline) {
        Logs().v(
            'Limited timeline for ${rooms[roomIndex].id} request history now');
        runInRoot(rooms[roomIndex].requestHistory);
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
        final stateEvent = Event.fromJson(eventUpdate.content, room);
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
          if (stateEvent.type != EventTypes.Message ||
              stateEvent.relationshipType != RelationshipTypes.edit ||
              stateEvent.relationshipEventId == room.lastEvent?.eventId ||
              ((room.lastEvent?.relationshipType == RelationshipTypes.edit &&
                  stateEvent.relationshipEventId ==
                      room.lastEvent?.relationshipEventId))) {
            room.setState(stateEvent);
          }
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

  /// If `true` then unread rooms are pinned at the top of the room list.
  bool pinInvitedRooms;

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
    rooms.sort(sortRoomsBy);
    _sortLock = false;
  }

  Future? userDeviceKeysLoading;
  Future? roomsLoading;
  Future? accountDataLoading;

  /// A map of known device keys per user.
  Map<String, DeviceKeysList> get userDeviceKeys => _userDeviceKeys;
  Map<String, DeviceKeysList> _userDeviceKeys = {};

  /// Gets user device keys by its curve25519 key. Returns null if it isn't found
  DeviceKeys? getUserDeviceKeysByCurve25519Key(String senderKey) {
    for (final user in userDeviceKeys.values) {
      final device = user.deviceKeys.values
          .firstWhereOrNull((e) => e.curve25519Key == senderKey);
      if (device != null) {
        return device;
      }
    }
    return null;
  }

  Future<Set<String>> _getUserIdsInEncryptedRooms() async {
    final userIds = <String>{};
    for (final room in rooms) {
      if (room.encrypted) {
        try {
          final userList = await room.requestParticipants();
          for (final user in userList) {
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

  Future<void> updateUserDeviceKeys() async {
    try {
      final database = this.database;
      if (!isLogged() || database == null) return;
      final dbActions = <Future<dynamic> Function()>[];
      final trackedUserIds = await _getUserIdsInEncryptedRooms();
      if (!isLogged()) return;
      trackedUserIds.add(userID!);

      // Remove all userIds we no longer need to track the devices of.
      _userDeviceKeys
          .removeWhere((String userId, v) => !trackedUserIds.contains(userId));

      // Check if there are outdated device key lists. Add it to the set.
      final outdatedLists = <String, List<String>>{};
      for (final userId in trackedUserIds) {
        final deviceKeysList =
            _userDeviceKeys[userId] ??= DeviceKeysList(userId, this);
        final failure = _keyQueryFailures[userId.domain];

        // deviceKeysList.outdated is not nullable but we have seen this error
        // in production: `Failed assertion: boolean expression must not be null`
        // So this could either be a null safety bug in Dart or a result of
        // using unsound null safety. The extra equal check `!= false` should
        // save us here.
        if (deviceKeysList.outdated != false &&
            (failure == null ||
                DateTime.now()
                    .subtract(Duration(minutes: 5))
                    .isAfter(failure))) {
          outdatedLists[userId] = [];
        }
      }

      if (outdatedLists.isNotEmpty) {
        // Request the missing device key lists from the server.
        final response = await queryKeys(outdatedLists, timeout: 10000);
        if (!isLogged()) return;

        final deviceKeys = response.deviceKeys;
        if (deviceKeys != null) {
          for (final rawDeviceKeyListEntry in deviceKeys.entries) {
            final userId = rawDeviceKeyListEntry.key;
            final userKeys =
                _userDeviceKeys[userId] ??= DeviceKeysList(userId, this);
            final oldKeys = Map<String, DeviceKeys>.from(userKeys.deviceKeys);
            userKeys.deviceKeys = {};
            for (final rawDeviceKeyEntry
                in rawDeviceKeyListEntry.value.entries) {
              final deviceId = rawDeviceKeyEntry.key;

              // Set the new device key for this device
              final entry = DeviceKeys.fromMatrixDeviceKeys(
                  rawDeviceKeyEntry.value, this, oldKeys[deviceId]?.lastActive);
              final ed25519Key = entry.ed25519Key;
              final curve25519Key = entry.curve25519Key;
              if (entry.isValid &&
                  deviceId == entry.deviceId &&
                  ed25519Key != null &&
                  curve25519Key != null) {
                // Check if deviceId or deviceKeys are known
                if (!oldKeys.containsKey(deviceId)) {
                  final oldPublicKeys =
                      await database.deviceIdSeen(userId, deviceId);
                  if (oldPublicKeys != null &&
                      oldPublicKeys != curve25519Key + ed25519Key) {
                    Logs().w(
                        'Already seen Device ID has been added again. This might be an attack!');
                    continue;
                  }
                  final oldDeviceId = await database.publicKeySeen(ed25519Key);
                  if (oldDeviceId != null && oldDeviceId != deviceId) {
                    Logs().w(
                        'Already seen ED25519 has been added again. This might be an attack!');
                    continue;
                  }
                  final oldDeviceId2 =
                      await database.publicKeySeen(curve25519Key);
                  if (oldDeviceId2 != null && oldDeviceId2 != deviceId) {
                    Logs().w(
                        'Already seen Curve25519 has been added again. This might be an attack!');
                    continue;
                  }
                  await database.addSeenDeviceId(
                      userId, deviceId, curve25519Key + ed25519Key);
                  await database.addSeenPublicKey(ed25519Key, deviceId);
                  await database.addSeenPublicKey(curve25519Key, deviceId);
                }

                // is this a new key or the same one as an old one?
                // better store an update - the signatures might have changed!
                final oldKey = oldKeys[deviceId];
                if (oldKey == null ||
                    (oldKey.ed25519Key == entry.ed25519Key &&
                        oldKey.curve25519Key == entry.curve25519Key)) {
                  if (oldKey != null) {
                    // be sure to save the verified status
                    entry.setDirectVerified(oldKey.directVerified);
                    entry.blocked = oldKey.blocked;
                    entry.validSignatures = oldKey.validSignatures;
                  }
                  userKeys.deviceKeys[deviceId] = entry;
                  if (deviceId == deviceID &&
                      entry.ed25519Key == fingerprintKey) {
                    // Always trust the own device
                    entry.setDirectVerified(true);
                  }
                  dbActions.add(() => database.storeUserDeviceKey(
                        userId,
                        deviceId,
                        json.encode(entry.toJson()),
                        entry.directVerified,
                        entry.blocked,
                        entry.lastActive.millisecondsSinceEpoch,
                      ));
                } else if (oldKeys.containsKey(deviceId)) {
                  // This shouldn't ever happen. The same device ID has gotten
                  // a new public key. So we ignore the update. TODO: ask krille
                  // if we should instead use the new key with unknown verified / blocked status
                  userKeys.deviceKeys[deviceId] = oldKeys[deviceId]!;
                }
              } else {
                Logs().w('Invalid device ${entry.userId}:${entry.deviceId}');
              }
            }
            // delete old/unused entries
            for (final oldDeviceKeyEntry in oldKeys.entries) {
              final deviceId = oldDeviceKeyEntry.key;
              if (!userKeys.deviceKeys.containsKey(deviceId)) {
                // we need to remove an old key
                dbActions
                    .add(() => database.removeUserDeviceKey(userId, deviceId));
              }
            }
            userKeys.outdated = false;
            dbActions
                .add(() => database.storeUserDeviceKeysInfo(userId, false));
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
            final userKeys =
                _userDeviceKeys[userId] ??= DeviceKeysList(userId, this);
            final oldKeys =
                Map<String, CrossSigningKey>.from(userKeys.crossSigningKeys);
            userKeys.crossSigningKeys = {};
            // add the types we aren't handling atm back
            for (final oldEntry in oldKeys.entries) {
              if (!oldEntry.value.usage.contains(keyType)) {
                userKeys.crossSigningKeys[oldEntry.key] = oldEntry.value;
              } else {
                // There is a previous cross-signing key with  this usage, that we no
                // longer need/use. Clear it from the database.
                dbActions.add(() =>
                    database.removeUserCrossSigningKey(userId, oldEntry.key));
              }
            }
            final entry = CrossSigningKey.fromMatrixCrossSigningKey(
                crossSigningKeyListEntry.value, this);
            final publicKey = entry.publicKey;
            if (entry.isValid && publicKey != null) {
              final oldKey = oldKeys[publicKey];
              if (oldKey == null || oldKey.ed25519Key == entry.ed25519Key) {
                if (oldKey != null) {
                  // be sure to save the verification status
                  entry.setDirectVerified(oldKey.directVerified);
                  entry.blocked = oldKey.blocked;
                  entry.validSignatures = oldKey.validSignatures;
                }
                userKeys.crossSigningKeys[publicKey] = entry;
              } else {
                // This shouldn't ever happen. The same device ID has gotten
                // a new public key. So we ignore the update. TODO: ask krille
                // if we should instead use the new key with unknown verified / blocked status
                userKeys.crossSigningKeys[publicKey] = oldKey;
              }
              dbActions.add(() => database.storeUserCrossSigningKey(
                    userId,
                    publicKey,
                    json.encode(entry.toJson()),
                    entry.directVerified,
                    entry.blocked,
                  ));
            }
            _userDeviceKeys[userId]?.outdated = false;
            dbActions
                .add(() => database.storeUserDeviceKeysInfo(userId, false));
          }
        }

        // now process all the failures
        if (response.failures != null) {
          for (final failureDomain in response.failures?.keys ?? <String>[]) {
            _keyQueryFailures[failureDomain] = DateTime.now();
          }
        }
      }

      if (dbActions.isNotEmpty) {
        if (!isLogged()) return;
        await database.transaction(() async {
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
    final database = this.database;
    if (database == null || !_toDeviceQueueNeedsProcessing) {
      return;
    }
    final entries = await database.getToDeviceEventQueue();
    if (entries.isEmpty) {
      _toDeviceQueueNeedsProcessing = false;
      return;
    }
    for (final entry in entries) {
      // Convert the Json Map to the correct format regarding
      // https: //matrix.org/docs/spec/client_server/r0.6.1#put-matrix-client-r0-sendtodevice-eventtype-txnid
      final data = entry.content.map((k, v) =>
          MapEntry<String, Map<String, Map<String, dynamic>>>(
              k,
              (v as Map).map((k, v) => MapEntry<String, Map<String, dynamic>>(
                  k, Map<String, dynamic>.from(v)))));

      await super.sendToDevice(entry.type, entry.txnId, data);
      await database.deleteFromToDeviceQueue(entry.id);
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
      final database = this.database;
      if (database != null) {
        _toDeviceQueueNeedsProcessing = true;
        await database.insertIntoToDeviceQueue(
            eventType, txnId, json.encode(messages));
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
    String? messageId,
  }) async {
    // Send with send-to-device messaging
    final data = <String, Map<String, Map<String, dynamic>>>{};
    for (final user in users) {
      data[user] = {'*': message};
    }
    await sendToDevice(
        eventType, messageId ?? generateUniqueTransactionId(), data);
    return;
  }

  final MultiLock<DeviceKeys> _sendToDeviceEncryptedLock = MultiLock();

  /// Sends an encrypted [message] of this [eventType] to these [deviceKeys].
  Future<void> sendToDeviceEncrypted(
    List<DeviceKeys> deviceKeys,
    String eventType,
    Map<String, dynamic> message, {
    String? messageId,
    bool onlyVerified = false,
  }) async {
    final encryption = this.encryption;
    if (!encryptionEnabled || encryption == null) return;
    // Don't send this message to blocked devices, and if specified onlyVerified
    // then only send it to verified devices
    if (deviceKeys.isNotEmpty) {
      deviceKeys.removeWhere((DeviceKeys deviceKeys) =>
          deviceKeys.blocked ||
          (deviceKeys.userId == userID && deviceKeys.deviceId == deviceID) ||
          (onlyVerified && !deviceKeys.verified));
      if (deviceKeys.isEmpty) return;
    }

    // So that we can guarantee order of encrypted to_device messages to be preserved we
    // must ensure that we don't attempt to encrypt multiple concurrent to_device messages
    // to the same device at the same time.
    // A failure to do so can result in edge-cases where encryption and sending order of
    // said to_device messages does not match up, resulting in an olm session corruption.
    // As we send to multiple devices at the same time, we may only proceed here if the lock for
    // *all* of them is freed and lock *all* of them while sending.

    try {
      await _sendToDeviceEncryptedLock.lock(deviceKeys);

      // Send with send-to-device messaging
      final data = await encryption.encryptToDeviceMessage(
              deviceKeys, eventType, message)
          as Map<String, Map<String, Map<String, dynamic>>>;
      eventType = EventTypes.Encrypted;
      await sendToDevice(
          eventType, messageId ?? generateUniqueTransactionId(), data);
    } finally {
      _sendToDeviceEncryptedLock.unlock(deviceKeys);
    }
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
      // ignore: unawaited_futures
      () async {
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
          // ignore: unawaited_futures
          sendToDeviceEncrypted(chunk, eventType, message);
        }
      }();
    }
  }

  /// Whether all push notifications are muted using the [.m.rule.master]
  /// rule of the push rules: https://matrix.org/docs/spec/client_server/r0.6.0#m-rule-master
  bool get allPushNotificationsMuted {
    final Map<String, dynamic>? globalPushRules =
        accountData['m.push_rules']?.content['global'];
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
    await setPushRuleEnabled(
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
      {String? oldPassword,
      AuthenticationData? auth,
      bool? logoutDevices}) async {
    final userID = this.userID;
    if (userID == null) return;
    try {
      if (oldPassword != null) {
        auth = AuthenticationPassword(
          identifier: AuthenticationUserIdentifier(user: userID),
          password: oldPassword,
        );
      }
      await super.changePassword(newPassword,
          auth: auth, logoutDevices: logoutDevices);
    } on MatrixException catch (matrixException) {
      if (!matrixException.requireAdditionalAuthentication) {
        rethrow;
      }
      if (matrixException.authenticationFlows?.length != 1 ||
          !(matrixException.authenticationFlows?.first.stages
                  .contains(AuthenticationTypes.password) ??
              false)) {
        rethrow;
      }
      if (oldPassword == null) {
        rethrow;
      }
      return changePassword(
        newPassword,
        auth: AuthenticationPassword(
          identifier: AuthenticationUserIdentifier(user: userID),
          password: oldPassword,
          session: matrixException.session,
        ),
        logoutDevices: logoutDevices,
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
    await database?.clearCache();
    encryption?.keyManager.clearOutboundGroupSessions();
    onCacheCleared.add(true);
    // Restart the syncloop
    backgroundSync = true;
  }

  /// A list of mxids of users who are ignored.
  List<String> get ignoredUsers => (accountData
              .containsKey('m.ignored_user_list') &&
          accountData['m.ignored_user_list']?.content['ignored_users'] is Map)
      ? List<String>.from(
          accountData['m.ignored_user_list']?.content['ignored_users'].keys)
      : [];

  /// Ignore another user. This will clear the local cached messages to
  /// hide all previous messages from this user.
  Future<void> ignoreUser(String userId) async {
    if (!userId.isValidMatrixId) {
      throw Exception('$userId is not a valid mxid!');
    }
    await setAccountData(userID!, 'm.ignored_user_list', {
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
    await setAccountData(userID!, 'm.ignored_user_list', {
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
      if (closeDatabase) {
        await database
            ?.close()
            .catchError((e, s) => Logs().w('Failed to close database: ', e, s));
        _database = null;
      }
    } catch (error, stacktrace) {
      Logs().w('Failed to close database: ', error, stacktrace);
    }
    return;
  }

  Future<void> _migrateFromLegacyDatabase() async {
    Logs().i('Check legacy database for migration data...');
    final legacyDatabase = await legacyDatabaseBuilder?.call(this);
    final migrateClient = await legacyDatabase?.getClient(clientName);
    final database = this.database;

    if (migrateClient != null && legacyDatabase != null && database != null) {
      Logs().i('Found data in the legacy database!');
      _id = migrateClient['client_id'];
      await database.insertClient(
        clientName,
        migrateClient['homeserver_url'],
        migrateClient['token'],
        migrateClient['user_id'],
        migrateClient['device_id'],
        migrateClient['device_name'],
        null,
        migrateClient['olm_account'],
      );
      Logs().d('Migrate SSSSCache...');
      for (final type in cacheTypes) {
        final ssssCache = await legacyDatabase.getSSSSCache(type);
        if (ssssCache != null) {
          Logs().d('Migrate $type...');
          await database.storeSSSSCache(
            type,
            ssssCache.keyId ?? '',
            ssssCache.ciphertext ?? '',
            ssssCache.content ?? '',
          );
        }
      }
      Logs().d('Migrate Device Keys...');
      final userDeviceKeys = await legacyDatabase.getUserDeviceKeys(this);
      for (final userId in userDeviceKeys.keys) {
        Logs().d('Migrate Device Keys of user $userId...');
        final deviceKeysList = userDeviceKeys[userId];
        for (final crossSigningKey
            in deviceKeysList?.crossSigningKeys.values ?? <CrossSigningKey>[]) {
          final pubKey = crossSigningKey.publicKey;
          if (pubKey != null) {
            Logs().d(
                'Migrate cross signing key with usage ${crossSigningKey.usage} and verified ${crossSigningKey.directVerified}...');
            await database.storeUserCrossSigningKey(
              userId,
              pubKey,
              jsonEncode(crossSigningKey.toJson()),
              crossSigningKey.directVerified,
              crossSigningKey.blocked,
            );
          }
        }

        if (deviceKeysList != null) {
          for (final deviceKeys in deviceKeysList.deviceKeys.values) {
            final deviceId = deviceKeys.deviceId;
            if (deviceId != null) {
              Logs().d('Migrate device keys for ${deviceKeys.deviceId}...');
              await database.storeUserDeviceKey(
                userId,
                deviceId,
                jsonEncode(deviceKeys.toJson()),
                deviceKeys.directVerified,
                deviceKeys.blocked,
                deviceKeys.lastActive.millisecondsSinceEpoch,
              );
            }
          }
          Logs().d('Migrate user device keys info...');
          await database.storeUserDeviceKeysInfo(
              userId, deviceKeysList.outdated);
        }
      }
      Logs().d('Migrate inbound group sessions...');
      try {
        final sessions = await legacyDatabase.getAllInboundGroupSessions();
        for (var i = 0; i < sessions.length; i++) {
          Logs().d('$i / ${sessions.length}');
          final session = sessions[i];
          await database.storeInboundGroupSession(
            session.roomId,
            session.sessionId,
            session.pickle,
            session.content,
            session.indexes,
            session.allowedAtIndex,
            session.senderKey,
            session.senderClaimedKeys,
          );
        }
      } catch (e, s) {
        Logs().e('Unable to migrate inbound group sessions!', e, s);
      }

      await legacyDatabase.clear();
      await legacyDatabaseDestroyer?.call(this);
    }
    await legacyDatabase?.close();
    _initLock = false;
    if (migrateClient != null) {
      return init();
    }
  }
}

class SdkError {
  dynamic exception;
  StackTrace? stackTrace;

  SdkError({this.exception, this.stackTrace});
}

class SyncStatusUpdate {
  final SyncStatus status;
  final SdkError? error;
  final double? progress;
  const SyncStatusUpdate(this.status, {this.error, this.progress});
}

enum SyncStatus {
  waitingForResponse,
  processing,
  cleaningUp,
  finished,
  error,
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
