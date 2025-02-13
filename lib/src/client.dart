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
import 'dart:math';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:olm/olm.dart' as olm;
import 'package:random_string/random_string.dart';

import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/matrix_api_lite/generated/fixed_model.dart';
import 'package:matrix/msc_extensions/msc_unpublished_custom_refresh_token_lifetime/msc_unpublished_custom_refresh_token_lifetime.dart';
import 'package:matrix/src/models/timeline_chunk.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:matrix/src/utils/client_init_exception.dart';
import 'package:matrix/src/utils/compute_callback.dart';
import 'package:matrix/src/utils/multilock.dart';
import 'package:matrix/src/utils/run_benchmarked.dart';
import 'package:matrix/src/utils/run_in_root.dart';
import 'package:matrix/src/utils/sync_update_item_count.dart';
import 'package:matrix/src/utils/try_get_push_rule.dart';
import 'package:matrix/src/utils/versions_comparator.dart';
import 'package:matrix/src/voip/utils/async_cache_try_fetch.dart';

typedef RoomSorter = int Function(Room a, Room b);

enum LoginState { loggedIn, loggedOut, softLoggedOut }

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
  DatabaseApi? _database;

  DatabaseApi? get database => _database;

  Encryption? get encryption => _encryption;
  Encryption? _encryption;

  Set<KeyVerificationMethod> verificationMethods;

  Set<String> importantStateEvents;

  Set<String> roomPreviewLastEvents;

  Set<String> supportedLoginTypes;

  bool requestHistoryOnLimitedTimeline;

  final bool formatLocalpart;

  final bool mxidLocalPartFallback;

  ShareKeysWith shareKeysWith;

  Future<void> Function(Client client)? onSoftLogout;

  DateTime? get accessTokenExpiresAt => _accessTokenExpiresAt;
  DateTime? _accessTokenExpiresAt;

  // For CommandsClientExtension
  final Map<String, CommandExecutionCallback> commands = {};
  final Filter syncFilter;

  final NativeImplementations nativeImplementations;

  String? _syncFilterId;

  String? get syncFilterId => _syncFilterId;

  final bool convertLinebreaksInFormatting;

  final ComputeCallback? compute;

  @Deprecated('Use [nativeImplementations] instead')
  Future<T> runInBackground<T, U>(
    FutureOr<T> Function(U arg) function,
    U arg,
  ) async {
    final compute = this.compute;
    if (compute != null) {
      return await compute(function, arg);
    }
    return await function(arg);
  }

  final Duration sendTimelineEventTimeout;

  /// The timeout until a typing indicator gets removed automatically.
  final Duration typingIndicatorTimeout;

  DiscoveryInformation? _wellKnown;

  /// the cached .well-known file updated using [getWellknown]
  DiscoveryInformation? get wellKnown => _wellKnown;

  /// The homeserver this client is communicating with.
  ///
  /// In case the [homeserver]'s host differs from the previous value, the
  /// [wellKnown] cache will be invalidated.
  @override
  set homeserver(Uri? homeserver) {
    if (this.homeserver != null && homeserver?.host != this.homeserver?.host) {
      _wellKnown = null;
      unawaited(database?.storeWellKnown(null));
    }
    super.homeserver = homeserver;
  }

  Future<MatrixImageFileResizedResponse?> Function(
    MatrixImageFileResizeArguments,
  )? customImageResizer;

  /// Create a client
  /// [clientName] = unique identifier of this client
  /// [databaseBuilder]: A function that creates the database instance, that will be used.
  /// [legacyDatabaseBuilder]: Use this for your old database implementation to perform an automatic migration
  /// [databaseDestroyer]: A function that can be used to destroy a database instance, for example by deleting files from disk.
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
  /// Set [nativeImplementations] to [NativeImplementationsIsolate] in order to
  /// enable the SDK to compute some code in background.
  /// Set [timelineEventTimeout] to the preferred time the Client should retry
  /// sending events on connection problems or to `Duration.zero` to disable it.
  /// Set [customImageResizer] to your own implementation for a more advanced
  /// and faster image resizing experience.
  /// Set [enableDehydratedDevices] to enable experimental support for enabling MSC3814 dehydrated devices.
  Client(
    this.clientName, {
    this.databaseBuilder,
    this.legacyDatabaseBuilder,
    Set<KeyVerificationMethod>? verificationMethods,
    http.Client? httpClient,
    Set<String>? importantStateEvents,

    /// You probably don't want to add state events which are also
    /// in important state events to this list, or get ready to face
    /// only having one event of that particular type in preLoad because
    /// previewEvents are stored with stateKey '' not the actual state key
    /// of your state event
    Set<String>? roomPreviewLastEvents,
    this.pinUnreadRooms = false,
    this.pinInvitedRooms = true,
    @Deprecated('Use [sendTimelineEventTimeout] instead.')
    int? sendMessageTimeoutSeconds,
    this.requestHistoryOnLimitedTimeline = false,
    Set<String>? supportedLoginTypes,
    this.mxidLocalPartFallback = true,
    this.formatLocalpart = true,
    @Deprecated('Use [nativeImplementations] instead') this.compute,
    NativeImplementations nativeImplementations = NativeImplementations.dummy,
    Level? logLevel,
    Filter? syncFilter,
    Duration defaultNetworkRequestTimeout = const Duration(seconds: 35),
    this.sendTimelineEventTimeout = const Duration(minutes: 1),
    this.customImageResizer,
    this.shareKeysWith = ShareKeysWith.crossVerifiedIfEnabled,
    this.enableDehydratedDevices = false,
    this.receiptsPublicByDefault = true,

    /// Implement your https://spec.matrix.org/v1.9/client-server-api/#soft-logout
    /// logic here.
    /// Set this to `refreshAccessToken()` for the easiest way to handle the
    /// most common reason for soft logouts.
    /// You can also perform a new login here by passing the existing deviceId.
    this.onSoftLogout,

    /// Experimental feature which allows to send a custom refresh token
    /// lifetime to the server which overrides the default one. Needs server
    /// support.
    this.customRefreshTokenLifetime,
    this.typingIndicatorTimeout = const Duration(seconds: 30),

    /// When sending a formatted message, converting linebreaks in markdown to
    /// <br/> tags:
    this.convertLinebreaksInFormatting = true,
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
        verificationMethods = verificationMethods ?? <KeyVerificationMethod>{},
        nativeImplementations = compute != null
            ? NativeImplementationsIsolate(compute)
            : nativeImplementations,
        super(
          httpClient: FixedTimeoutHttpClient(
            httpClient ?? http.Client(),
            defaultNetworkRequestTimeout,
          ),
        ) {
    if (logLevel != null) Logs().level = logLevel;
    importantStateEvents.addAll([
      EventTypes.RoomName,
      EventTypes.RoomAvatar,
      EventTypes.Encryption,
      EventTypes.RoomCanonicalAlias,
      EventTypes.RoomTombstone,
      EventTypes.SpaceChild,
      EventTypes.SpaceParent,
      EventTypes.RoomCreate,
    ]);
    roomPreviewLastEvents.addAll([
      EventTypes.Message,
      EventTypes.Encrypted,
      EventTypes.Sticker,
      EventTypes.CallInvite,
      EventTypes.CallAnswer,
      EventTypes.CallReject,
      EventTypes.CallHangup,
      EventTypes.GroupCallMember,
    ]);

    // register all the default commands
    registerDefaultCommands();
  }

  Duration? customRefreshTokenLifetime;

  /// Fetches the refreshToken from the database and tries to get a new
  /// access token from the server and then stores it correctly. Unlike the
  /// pure API call of `Client.refresh()` this handles the complete soft
  /// logout case.
  /// Throws an Exception if there is no refresh token available or the
  /// client is not logged in.
  Future<void> refreshAccessToken() async {
    final storedClient = await database?.getClient(clientName);
    final refreshToken = storedClient?.tryGet<String>('refresh_token');
    if (refreshToken == null) {
      throw Exception('No refresh token available');
    }
    final homeserverUrl = homeserver?.toString();
    final userId = userID;
    final deviceId = deviceID;
    if (homeserverUrl == null || userId == null || deviceId == null) {
      throw Exception('Cannot refresh access token when not logged in');
    }

    final tokenResponse = await refreshWithCustomRefreshTokenLifetime(
      refreshToken,
      refreshTokenLifetimeMs: customRefreshTokenLifetime?.inMilliseconds,
    );

    accessToken = tokenResponse.accessToken;
    final expiresInMs = tokenResponse.expiresInMs;
    final tokenExpiresAt = expiresInMs == null
        ? null
        : DateTime.now().add(Duration(milliseconds: expiresInMs));
    _accessTokenExpiresAt = tokenExpiresAt;
    await database?.updateClient(
      homeserverUrl,
      tokenResponse.accessToken,
      tokenExpiresAt,
      tokenResponse.refreshToken,
      userId,
      deviceId,
      deviceName,
      prevBatch,
      encryption?.pickledOlmAccount,
    );
  }

  /// The required name for this client.
  final String clientName;

  /// The Matrix ID of the current logged user.
  String? get userID => _userID;
  String? _userID;

  /// This points to the position in the synchronization history.
  String? get prevBatch => _prevBatch;
  String? _prevBatch;

  /// The device ID is an unique identifier for this device.
  String? get deviceID => _deviceID;
  String? _deviceID;

  /// The device name is a human readable identifier for this device.
  String? get deviceName => _deviceName;
  String? _deviceName;

  // for group calls
  // A unique identifier used for resolving duplicate group call
  // sessions from a given device. When the session_id field changes from
  // an incoming m.call.member event, any existing calls from this device in
  // this call should be terminated. The id is generated once per client load.
  String? get groupCallSessionId => _groupCallSessionId;
  String? _groupCallSessionId;

  /// Returns the current login state.
  @Deprecated('Use [onLoginStateChanged.value] instead')
  LoginState get loginState =>
      onLoginStateChanged.value ?? LoginState.loggedOut;

  bool isLogged() => accessToken != null;

  /// A list of all rooms the user is participating or invited.
  List<Room> get rooms => _rooms;
  List<Room> _rooms = [];

  /// Get a list of the archived rooms
  ///
  /// Attention! Archived rooms are only returned if [loadArchive()] was called
  /// beforehand! The state refers to the last retrieval via [loadArchive()]!
  List<ArchivedRoom> get archivedRooms => _archivedRooms;

  bool enableDehydratedDevices = false;

  /// Whether read receipts are sent as public receipts by default or just as private receipts.
  bool receiptsPublicByDefault = true;

  /// Whether this client supports end-to-end encryption using olm.
  bool get encryptionEnabled => encryption?.enabled == true;

  /// Whether this client is able to encrypt and decrypt files.
  bool get fileEncryptionEnabled => encryptionEnabled;

  String get identityKey => encryption?.identityKey ?? '';

  String get fingerprintKey => encryption?.fingerprintKey ?? '';

  /// Whether this session is unknown to others
  bool get isUnknownSession =>
      userDeviceKeys[userID]?.deviceKeys[deviceID]?.signed != true;

  /// Warning! This endpoint is for testing only!
  set rooms(List<Room> newList) {
    Logs().w('Warning! This endpoint is for testing only!');
    _rooms = newList;
  }

  /// Key/Value store of account data.
  Map<String, BasicEvent> _accountData = {};

  Map<String, BasicEvent> get accountData => _accountData;

  /// Evaluate if an event should notify quickly
  PushruleEvaluator get pushruleEvaluator =>
      _pushruleEvaluator ?? PushruleEvaluator.fromRuleset(PushRuleSet());
  PushruleEvaluator? _pushruleEvaluator;

  void _updatePushrules() {
    final ruleset = TryGetPushRule.tryFromJson(
      _accountData[EventTypes.PushRules]
              ?.content
              .tryGetMap<String, Object?>('global') ??
          {},
    );
    _pushruleEvaluator = PushruleEvaluator.fromRuleset(ruleset);
  }

  /// Presences of users by a given matrix ID
  @Deprecated('Use `fetchCurrentPresence(userId)` instead.')
  Map<String, CachedPresence> presences = {};

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
    for (final room in <Room>[...rooms, ..._archivedRooms.map((e) => e.room)]) {
      if (room.id == id) return room;
    }

    return null;
  }

  Map<String, List<String>> get directChats =>
      (_accountData['m.direct']?.content ?? {}).map(
        (userId, list) => MapEntry(
          userId,
          (list is! List) ? [] : list.whereType<String>().toList(),
        ),
      );

  /// Returns the (first) room ID from the store which is a private chat with the user [userId].
  /// Returns null if there is none.
  String? getDirectChatFromUserId(String userId) {
    final directChats = _accountData['m.direct']?.content[userId];
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
          final prevLast = prev.lastEvent?.originServerTs ?? DateTime(0);
          final rLast = r.lastEvent?.originServerTs ?? DateTime(0);

          return rLast.isAfter(prevLast) ? r : prev;
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
      final response = await httpClient.get(
        Uri.https(
          MatrixIdOrDomain.domain ?? '',
          '/.well-known/matrix/client',
        ),
      );
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
          baseUrl: Uri.https(MatrixIdOrDomain.domain ?? '', ''),
        ),
      );
    }
  }

  /// Checks the supported versions of the Matrix protocol and the supported
  /// login types. Throws an exception if the server is not compatible with the
  /// client and sets [homeserver] to [homeserverUrl] if it is. Supports the
  /// types `Uri` and `String`.
  Future<
      (
        DiscoveryInformation?,
        GetVersionsResponse versions,
        List<LoginFlow>,
      )> checkHomeserver(
    Uri homeserverUrl, {
    bool checkWellKnown = true,
    Set<String>? overrideSupportedVersions,
  }) async {
    final supportedVersions =
        overrideSupportedVersions ?? Client.supportedVersions;
    try {
      homeserver = homeserverUrl.stripTrailingSlash();

      // Look up well known
      DiscoveryInformation? wellKnown;
      if (checkWellKnown) {
        try {
          wellKnown = await getWellknown();
          homeserver = wellKnown.mHomeserver.baseUrl.stripTrailingSlash();
        } catch (e) {
          Logs().v('Found no well known information', e);
        }
      }

      // Check if server supports at least one supported version
      final versions = await getVersions();
      if (!versions.versions
          .any((version) => supportedVersions.contains(version))) {
        Logs().w(
          'Server supports the versions: ${versions.toString()} but this application is only compatible with ${supportedVersions.toString()}.',
        );
        assert(false);
      }

      final loginTypes = await getLoginFlows() ?? [];
      if (!loginTypes.any((f) => supportedLoginTypes.contains(f.type))) {
        throw BadServerLoginTypesException(
          loginTypes.map((f) => f.type).toSet(),
          supportedLoginTypes,
        );
      }

      return (wellKnown, versions, loginTypes);
    } catch (_) {
      homeserver = null;
      rethrow;
    }
  }

  /// Gets discovery information about the domain. The file may include
  /// additional keys, which MUST follow the Java package naming convention,
  /// e.g. `com.example.myapp.property`. This ensures property names are
  /// suitably namespaced for each application and reduces the risk of
  /// clashes.
  ///
  /// Note that this endpoint is not necessarily handled by the homeserver,
  /// but by another webserver, to be used for discovering the homeserver URL.
  ///
  /// The result of this call is stored in [wellKnown] for later use at runtime.
  @override
  Future<DiscoveryInformation> getWellknown() async {
    final wellKnown = await super.getWellknown();

    // do not reset the well known here, so super call
    super.homeserver = wellKnown.mHomeserver.baseUrl.stripTrailingSlash();
    _wellKnown = wellKnown;
    await database?.storeWellKnown(wellKnown);
    return wellKnown;
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
    bool? refreshToken,
    AuthenticationData? auth,
    AccountKind? kind,
    void Function(InitState)? onInitStateChanged,
  }) async {
    final response = await super.register(
      kind: kind,
      username: username,
      password: password,
      auth: auth,
      deviceId: deviceId,
      initialDeviceDisplayName: initialDeviceDisplayName,
      inhibitLogin: inhibitLogin,
      refreshToken: refreshToken ?? onSoftLogout != null,
    );

    // Connect if there is an access token in the response.
    final accessToken = response.accessToken;
    final deviceId_ = response.deviceId;
    final userId = response.userId;
    final homeserver = this.homeserver;
    if (accessToken == null || deviceId_ == null || homeserver == null) {
      throw Exception(
        'Registered but token, device ID, user ID or homeserver is null.',
      );
    }
    final expiresInMs = response.expiresInMs;
    final tokenExpiresAt = expiresInMs == null
        ? null
        : DateTime.now().add(Duration(milliseconds: expiresInMs));

    await init(
      newToken: accessToken,
      newTokenExpiresAt: tokenExpiresAt,
      newRefreshToken: response.refreshToken,
      newUserID: userId,
      newHomeserver: homeserver,
      newDeviceName: initialDeviceDisplayName ?? '',
      newDeviceID: deviceId_,
      onInitStateChanged: onInitStateChanged,
    );
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
    String type, {
    AuthenticationIdentifier? identifier,
    String? password,
    String? token,
    String? deviceId,
    String? initialDeviceDisplayName,
    bool? refreshToken,
    @Deprecated('Deprecated in favour of identifier.') String? user,
    @Deprecated('Deprecated in favour of identifier.') String? medium,
    @Deprecated('Deprecated in favour of identifier.') String? address,
    void Function(InitState)? onInitStateChanged,
  }) async {
    if (homeserver == null) {
      final domain = identifier is AuthenticationUserIdentifier
          ? identifier.user.domain
          : null;
      if (domain != null) {
        await checkHomeserver(Uri.https(domain, ''));
      } else {
        throw Exception('No homeserver specified!');
      }
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
      refreshToken: refreshToken ?? onSoftLogout != null,
    );

    // Connect if there is an access token in the response.
    final accessToken = response.accessToken;
    final deviceId_ = response.deviceId;
    final userId = response.userId;
    final homeserver_ = homeserver;
    if (homeserver_ == null) {
      throw Exception('Registered but homerserver is null.');
    }

    final expiresInMs = response.expiresInMs;
    final tokenExpiresAt = expiresInMs == null
        ? null
        : DateTime.now().add(Duration(milliseconds: expiresInMs));

    await init(
      newToken: accessToken,
      newTokenExpiresAt: tokenExpiresAt,
      newRefreshToken: response.refreshToken,
      newUserID: userId,
      newHomeserver: homeserver_,
      newDeviceName: initialDeviceDisplayName ?? '',
      newDeviceID: deviceId_,
      onInitStateChanged: onInitStateChanged,
    );
    return response;
  }

  /// Sends a logout command to the homeserver and clears all local data,
  /// including all persistent data from the store.
  @override
  Future<void> logout() async {
    try {
      // Upload keys to make sure all are cached on the next login.
      await encryption?.keyManager.uploadInboundGroupSessions();
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
    // Upload keys to make sure all are cached on the next login.
    await encryption?.keyManager.uploadInboundGroupSessions();

    final futures = <Future>[];
    futures.add(super.logoutAll());
    futures.add(clear());
    await Future.wait(futures).catchError((e, s) {
      Logs().e('Logout all failed', e, s);
      throw e;
    });
  }

  /// Run any request and react on user interactive authentication flows here.
  Future<T> uiaRequestBackground<T>(
    Future<T> Function(AuthenticationData? auth) request,
  ) {
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
    Map<String, dynamic>? powerLevelContentOverride,
    CreateRoomPreset? preset = CreateRoomPreset.trustedPrivateChat,
  }) async {
    // Try to find an existing direct chat
    final directChatRoomId = getDirectChatFromUserId(mxid);
    if (directChatRoomId != null) {
      final room = getRoomById(directChatRoomId);
      if (room != null) {
        if (room.membership == Membership.join) {
          return directChatRoomId;
        } else if (room.membership == Membership.invite) {
          // we might already have an invite into a DM room. If that is the case, we should try to join. If the room is
          // unjoinable, that will automatically leave the room, so in that case we need to continue creating a new
          // room. (This implicitly also prevents the room from being returned as a DM room by getDirectChatFromUserId,
          // because it only returns joined or invited rooms atm.)
          await room.join();
          if (room.membership != Membership.leave) {
            if (waitForSync) {
              if (room.membership != Membership.join) {
                // Wait for room actually appears in sync with the right membership
                await waitForRoomInSync(directChatRoomId, join: true);
              }
            }
            return directChatRoomId;
          }
        }
      }
    }

    enableEncryption ??=
        encryptionEnabled && await userOwnsEncryptionKeys(mxid);
    if (enableEncryption) {
      initialState ??= [];
      if (!initialState.any((s) => s.type == EventTypes.Encryption)) {
        initialState.add(
          StateEvent(
            content: {
              'algorithm': supportedGroupEncryptionAlgorithms.first,
            },
            type: EventTypes.Encryption,
          ),
        );
      }
    }

    // Start a new direct chat
    final roomId = await createRoom(
      invite: [mxid],
      isDirect: true,
      preset: preset,
      initialState: initialState,
      powerLevelContentOverride: powerLevelContentOverride,
    );

    if (waitForSync) {
      final room = getRoomById(roomId);
      if (room == null || room.membership != Membership.join) {
        // Wait for room actually appears in sync
        await waitForRoomInSync(roomId, join: true);
      }
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
    HistoryVisibility? historyVisibility,
    bool waitForSync = true,
    bool groupCall = false,
    bool federated = true,
    Map<String, dynamic>? powerLevelContentOverride,
  }) async {
    enableEncryption ??=
        encryptionEnabled && preset != CreateRoomPreset.publicChat;
    if (enableEncryption) {
      initialState ??= [];
      if (!initialState.any((s) => s.type == EventTypes.Encryption)) {
        initialState.add(
          StateEvent(
            content: {
              'algorithm': supportedGroupEncryptionAlgorithms.first,
            },
            type: EventTypes.Encryption,
          ),
        );
      }
    }
    if (historyVisibility != null) {
      initialState ??= [];
      if (!initialState.any((s) => s.type == EventTypes.HistoryVisibility)) {
        initialState.add(
          StateEvent(
            content: {
              'history_visibility': historyVisibility.text,
            },
            type: EventTypes.HistoryVisibility,
          ),
        );
      }
    }
    if (groupCall) {
      powerLevelContentOverride ??= {};
      powerLevelContentOverride['events'] ??= {};
      powerLevelContentOverride['events'][EventTypes.GroupCallMember] ??=
          powerLevelContentOverride['events_default'] ?? 0;
    }

    final roomId = await createRoom(
      creationContent: federated ? null : {'m.federate': false},
      invite: invite,
      preset: preset,
      name: groupName,
      initialState: initialState,
      visibility: visibility,
      powerLevelContentOverride: powerLevelContentOverride,
    );

    if (waitForSync) {
      if (getRoomById(roomId) == null) {
        // Wait for room actually appears in sync
        await waitForRoomInSync(roomId, join: true);
      }
    }
    return roomId;
  }

  /// Wait for the room to appear into the enabled section of the room sync.
  /// By default, the function will listen for room in invite, join and leave
  /// sections of the sync.
  Future<SyncUpdate> waitForRoomInSync(
    String roomId, {
    bool join = false,
    bool invite = false,
    bool leave = false,
  }) async {
    if (!join && !invite && !leave) {
      join = true;
      invite = true;
      leave = true;
    }

    // Wait for the next sync where this room appears.
    final syncUpdate = await onSync.stream.firstWhere(
      (sync) =>
          invite && (sync.rooms?.invite?.containsKey(roomId) ?? false) ||
          join && (sync.rooms?.join?.containsKey(roomId) ?? false) ||
          leave && (sync.rooms?.leave?.containsKey(roomId) ?? false),
    );

    // Wait for this sync to be completely processed.
    await onSyncStatus.stream.firstWhere(
      (syncStatus) => syncStatus.status == SyncStatus.finished,
    );
    return syncUpdate;
  }

  /// Checks if the given user has encryption keys. May query keys from the
  /// server to answer this.
  Future<bool> userOwnsEncryptionKeys(String userId) async {
    if (userId == userID) return encryptionEnabled;
    if (_userDeviceKeys[userId]?.deviceKeys.isNotEmpty ?? false) {
      return true;
    }
    final keys = await queryKeys({userId: []});
    return keys.deviceKeys?[userId]?.isNotEmpty ?? false;
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
    bool waitForSync = false,
  }) async {
    final id = await createRoom(
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

    if (waitForSync) {
      await waitForRoomInSync(id, join: true);
    }

    return id;
  }

  @Deprecated('Use getUserProfile(userID) instead')
  Future<Profile> get ownProfile => fetchOwnProfile();

  /// Returns the user's own displayname and avatar url. In Matrix it is possible that
  /// one user can have different displaynames and avatar urls in different rooms.
  /// Tries to get the profile from homeserver first, if failed, falls back to a profile
  /// from a room where the user exists. Set `useServerCache` to true to get any
  /// prior value from this function
  @Deprecated('Use fetchOwnProfile() instead')
  Future<Profile> fetchOwnProfileFromServer({
    bool useServerCache = false,
  }) async {
    try {
      return await getProfileFromUserId(
        userID!,
        getFromRooms: false,
        cache: useServerCache,
      );
    } catch (e) {
      Logs().w(
        '[Matrix] getting profile from homeserver failed, falling back to first room with required profile',
      );
      return await getProfileFromUserId(
        userID!,
        getFromRooms: true,
        cache: true,
      );
    }
  }

  /// Returns the user's own displayname and avatar url. In Matrix it is possible that
  /// one user can have different displaynames and avatar urls in different rooms.
  /// This returns the profile from the first room by default, override `getFromRooms`
  /// to false to fetch from homeserver.
  Future<Profile> fetchOwnProfile({
    @Deprecated('No longer supported') bool getFromRooms = true,
    @Deprecated('No longer supported') bool cache = true,
  }) =>
      getProfileFromUserId(userID!);

  /// Get the combined profile information for this user. First checks for a
  /// non outdated cached profile before requesting from the server. Cached
  /// profiles are outdated if they have been cached in a time older than the
  /// [maxCacheAge] or they have been marked as outdated by an event in the
  /// sync loop.
  /// In case of an
  ///
  /// [userId] The user whose profile information to get.
  @override
  Future<CachedProfileInformation> getUserProfile(
    String userId, {
    Duration timeout = const Duration(seconds: 30),
    Duration maxCacheAge = const Duration(days: 1),
  }) async {
    final cachedProfile = await database?.getUserProfile(userId);
    if (cachedProfile != null &&
        !cachedProfile.outdated &&
        DateTime.now().difference(cachedProfile.updated) < maxCacheAge) {
      return cachedProfile;
    }

    final ProfileInformation profile;
    try {
      profile = await (_userProfileRequests[userId] ??=
          super.getUserProfile(userId).timeout(timeout));
    } catch (e) {
      Logs().d('Unable to fetch profile from server', e);
      if (cachedProfile == null) rethrow;
      return cachedProfile;
    } finally {
      unawaited(_userProfileRequests.remove(userId));
    }

    final newCachedProfile = CachedProfileInformation.fromProfile(
      profile,
      outdated: false,
      updated: DateTime.now(),
    );

    await database?.storeUserProfile(userId, newCachedProfile);

    return newCachedProfile;
  }

  final Map<String, Future<ProfileInformation>> _userProfileRequests = {};

  final CachedStreamController<String> onUserProfileUpdate =
      CachedStreamController<String>();

  /// Get the combined profile information for this user from the server or
  /// from the cache depending on the cache value. Returns a `Profile` object
  /// including the given userId but without information about how outdated
  /// the profile is. If you need those, try using `getUserProfile()` instead.
  Future<Profile> getProfileFromUserId(
    String userId, {
    @Deprecated('No longer supported') bool? getFromRooms,
    @Deprecated('No longer supported') bool? cache,
    Duration timeout = const Duration(seconds: 30),
    Duration maxCacheAge = const Duration(days: 1),
  }) async {
    CachedProfileInformation? cachedProfileInformation;
    try {
      cachedProfileInformation = await getUserProfile(
        userId,
        timeout: timeout,
        maxCacheAge: maxCacheAge,
      );
    } catch (e) {
      Logs().d('Unable to fetch profile for $userId', e);
    }

    return Profile(
      userId: userId,
      displayName: cachedProfileInformation?.displayname,
      avatarUrl: cachedProfileInformation?.avatarUrl,
    );
  }

  final List<ArchivedRoom> _archivedRooms = [];

  /// Return an archive room containing the room and the timeline for a specific archived room.
  ArchivedRoom? getArchiveRoomFromCache(String roomId) {
    for (var i = 0; i < _archivedRooms.length; i++) {
      final archive = _archivedRooms[i];
      if (archive.room.id == roomId) return archive;
    }
    return null;
  }

  /// Remove all the archives stored in cache.
  void clearArchivesFromCache() {
    _archivedRooms.clear();
  }

  @Deprecated('Use [loadArchive()] instead.')
  Future<List<Room>> get archive => loadArchive();

  /// Fetch all the archived rooms from the server and return the list of the
  /// room. If you want to have the Timelines bundled with it, use
  /// loadArchiveWithTimeline instead.
  Future<List<Room>> loadArchive() async {
    return (await loadArchiveWithTimeline()).map((e) => e.room).toList();
  }

  // Synapse caches sync responses. Documentation:
  // https://matrix-org.github.io/synapse/latest/usage/configuration/config_documentation.html#caches-and-associated-values
  // At the time of writing, the cache key consists of the following fields:  user, timeout, since, filter_id,
  // full_state, device_id, last_ignore_accdata_streampos.
  // Since we can't pass a since token, the easiest field to vary is the timeout to bust through the synapse cache and
  // give us the actual currently left rooms. Since the timeout doesn't matter for initial sync, this should actually
  // not make any visible difference apart from properly fetching the cached rooms.
  int _archiveCacheBusterTimeout = 0;

  /// Fetch the archived rooms from the server and return them as a list of
  /// [ArchivedRoom] objects containing the [Room] and the associated [Timeline].
  Future<List<ArchivedRoom>> loadArchiveWithTimeline() async {
    _archivedRooms.clear();

    final filter = jsonEncode(
      Filter(
        room: RoomFilter(
          state: StateFilter(lazyLoadMembers: true),
          includeLeave: true,
          timeline: StateFilter(limit: 10),
        ),
      ).toJson(),
    );

    final syncResp = await sync(
      filter: filter,
      timeout: _archiveCacheBusterTimeout,
      setPresence: syncPresence,
    );
    // wrap around and hope there are not more than 30 leaves in 2 minutes :)
    _archiveCacheBusterTimeout = (_archiveCacheBusterTimeout + 1) % 30;

    final leave = syncResp.rooms?.leave;
    if (leave != null) {
      for (final entry in leave.entries) {
        await _storeArchivedRoom(entry.key, entry.value);
      }
    }

    // Sort the archived rooms by last event originServerTs as this is the
    // best indicator we have to sort them. For archived rooms where we don't
    // have any, we move them to the bottom.
    final beginningOfTime = DateTime.fromMillisecondsSinceEpoch(0);
    _archivedRooms.sort(
      (b, a) => (a.room.lastEvent?.originServerTs ?? beginningOfTime)
          .compareTo(b.room.lastEvent?.originServerTs ?? beginningOfTime),
    );

    return _archivedRooms;
  }

  /// [_storeArchivedRoom]
  /// @leftRoom we can pass a room which was left so that we don't loose states
  Future<void> _storeArchivedRoom(
    String id,
    LeftRoomUpdate update, {
    Room? leftRoom,
  }) async {
    final roomUpdate = update;
    final archivedRoom = leftRoom ??
        Room(
          id: id,
          membership: Membership.leave,
          client: this,
          roomAccountData: roomUpdate.accountData
                  ?.asMap()
                  .map((k, v) => MapEntry(v.type, v)) ??
              <String, BasicEvent>{},
        );
    // Set membership of room to leave, in the case we got a left room passed, otherwise
    // the left room would have still membership join, which would be wrong for the setState later
    archivedRoom.membership = Membership.leave;
    final timeline = Timeline(
      room: archivedRoom,
      chunk: TimelineChunk(
        events: roomUpdate.timeline?.events?.reversed
                .toList() // we display the event in the other sence
                .map((e) => Event.fromMatrixEvent(e, archivedRoom))
                .toList() ??
            [],
      ),
    );

    archivedRoom.prev_batch = update.timeline?.prevBatch;

    final stateEvents = roomUpdate.state;
    if (stateEvents != null) {
      await _handleRoomEvents(
        archivedRoom,
        stateEvents,
        EventUpdateType.state,
        store: false,
      );
    }

    final timelineEvents = roomUpdate.timeline?.events;
    if (timelineEvents != null) {
      await _handleRoomEvents(
        archivedRoom,
        timelineEvents.reversed.toList(),
        EventUpdateType.timeline,
        store: false,
      );
    }

    for (var i = 0; i < timeline.events.length; i++) {
      // Try to decrypt encrypted events but don't update the database.
      if (archivedRoom.encrypted && archivedRoom.client.encryptionEnabled) {
        if (timeline.events[i].type == EventTypes.Encrypted) {
          await archivedRoom.client.encryption!
              .decryptRoomEvent(timeline.events[i])
              .then(
                (decrypted) => timeline.events[i] = decrypted,
              );
        }
      }
    }

    _archivedRooms.add(ArchivedRoom(room: archivedRoom, timeline: timeline));
  }

  final _versionsCache =
      AsyncCache<GetVersionsResponse>(const Duration(hours: 1));

  Future<bool> authenticatedMediaSupported() async {
    final versionsResponse = await _versionsCache.tryFetch(() => getVersions());
    return versionsResponse.versions.any(
          (v) => isVersionGreaterThanOrEqualTo(v, 'v1.11'),
        ) ||
        versionsResponse.unstableFeatures?['org.matrix.msc3916.stable'] == true;
  }

  final _serverConfigCache = AsyncCache<MediaConfig>(const Duration(hours: 1));

  /// This endpoint allows clients to retrieve the configuration of the content
  /// repository, such as upload limitations.
  /// Clients SHOULD use this as a guide when using content repository endpoints.
  /// All values are intentionally left optional. Clients SHOULD follow
  /// the advice given in the field description when the field is not available.
  ///
  /// **NOTE:** Both clients and server administrators should be aware that proxies
  /// between the client and the server may affect the apparent behaviour of content
  /// repository APIs, for example, proxies may enforce a lower upload size limit
  /// than is advertised by the server on this endpoint.
  @override
  Future<MediaConfig> getConfig() => _serverConfigCache.tryFetch(
        () async => (await authenticatedMediaSupported())
            ? getConfigAuthed()
            // ignore: deprecated_member_use_from_same_package
            : super.getConfig(),
      );

  ///
  ///
  /// [serverName] The server name from the `mxc://` URI (the authoritory component)
  ///
  ///
  /// [mediaId] The media ID from the `mxc://` URI (the path component)
  ///
  ///
  /// [allowRemote] Indicates to the server that it should not attempt to fetch the media if
  /// it is deemed remote. This is to prevent routing loops where the server
  /// contacts itself.
  ///
  /// Defaults to `true` if not provided.
  ///
  /// [timeoutMs] The maximum number of milliseconds that the client is willing to wait to
  /// start receiving data, in the case that the content has not yet been
  /// uploaded. The default value is 20000 (20 seconds). The content
  /// repository SHOULD impose a maximum value for this parameter. The
  /// content repository MAY respond before the timeout.
  ///
  ///
  /// [allowRedirect] Indicates to the server that it may return a 307 or 308 redirect
  /// response that points at the relevant media content. When not explicitly
  /// set to `true` the server must return the media content itself.
  ///
  @override
  Future<FileResponse> getContent(
    String serverName,
    String mediaId, {
    bool? allowRemote,
    int? timeoutMs,
    bool? allowRedirect,
  }) async {
    return (await authenticatedMediaSupported())
        ? getContentAuthed(
            serverName,
            mediaId,
            timeoutMs: timeoutMs,
          )
        // ignore: deprecated_member_use_from_same_package
        : super.getContent(
            serverName,
            mediaId,
            allowRemote: allowRemote,
            timeoutMs: timeoutMs,
            allowRedirect: allowRedirect,
          );
  }

  /// This will download content from the content repository (same as
  /// the previous endpoint) but replace the target file name with the one
  /// provided by the caller.
  ///
  /// {{% boxes/warning %}}
  /// {{< changed-in v="1.11" >}} This endpoint MAY return `404 M_NOT_FOUND`
  /// for media which exists, but is after the server froze unauthenticated
  /// media access. See [Client Behaviour](https://spec.matrix.org/unstable/client-server-api/#content-repo-client-behaviour) for more
  /// information.
  /// {{% /boxes/warning %}}
  ///
  /// [serverName] The server name from the `mxc://` URI (the authority component).
  ///
  ///
  /// [mediaId] The media ID from the `mxc://` URI (the path component).
  ///
  ///
  /// [fileName] A filename to give in the `Content-Disposition` header.
  ///
  /// [allowRemote] Indicates to the server that it should not attempt to fetch the media if
  /// it is deemed remote. This is to prevent routing loops where the server
  /// contacts itself.
  ///
  /// Defaults to `true` if not provided.
  ///
  /// [timeoutMs] The maximum number of milliseconds that the client is willing to wait to
  /// start receiving data, in the case that the content has not yet been
  /// uploaded. The default value is 20000 (20 seconds). The content
  /// repository SHOULD impose a maximum value for this parameter. The
  /// content repository MAY respond before the timeout.
  ///
  ///
  /// [allowRedirect] Indicates to the server that it may return a 307 or 308 redirect
  /// response that points at the relevant media content. When not explicitly
  /// set to `true` the server must return the media content itself.
  @override
  Future<FileResponse> getContentOverrideName(
    String serverName,
    String mediaId,
    String fileName, {
    bool? allowRemote,
    int? timeoutMs,
    bool? allowRedirect,
  }) async {
    return (await authenticatedMediaSupported())
        ? getContentOverrideNameAuthed(
            serverName,
            mediaId,
            fileName,
            timeoutMs: timeoutMs,
          )
        // ignore: deprecated_member_use_from_same_package
        : super.getContentOverrideName(
            serverName,
            mediaId,
            fileName,
            allowRemote: allowRemote,
            timeoutMs: timeoutMs,
            allowRedirect: allowRedirect,
          );
  }

  /// Download a thumbnail of content from the content repository.
  /// See the [Thumbnails](https://spec.matrix.org/unstable/client-server-api/#thumbnails) section for more information.
  ///
  /// {{% boxes/note %}}
  /// Clients SHOULD NOT generate or use URLs which supply the access token in
  /// the query string. These URLs may be copied by users verbatim and provided
  /// in a chat message to another user, disclosing the sender's access token.
  /// {{% /boxes/note %}}
  ///
  /// Clients MAY be redirected using the 307/308 responses below to download
  /// the request object. This is typical when the homeserver uses a Content
  /// Delivery Network (CDN).
  ///
  /// [serverName] The server name from the `mxc://` URI (the authority component).
  ///
  ///
  /// [mediaId] The media ID from the `mxc://` URI (the path component).
  ///
  ///
  /// [width] The *desired* width of the thumbnail. The actual thumbnail may be
  /// larger than the size specified.
  ///
  /// [height] The *desired* height of the thumbnail. The actual thumbnail may be
  /// larger than the size specified.
  ///
  /// [method] The desired resizing method. See the [Thumbnails](https://spec.matrix.org/unstable/client-server-api/#thumbnails)
  /// section for more information.
  ///
  /// [timeoutMs] The maximum number of milliseconds that the client is willing to wait to
  /// start receiving data, in the case that the content has not yet been
  /// uploaded. The default value is 20000 (20 seconds). The content
  /// repository SHOULD impose a maximum value for this parameter. The
  /// content repository MAY respond before the timeout.
  ///
  ///
  /// [animated] Indicates preference for an animated thumbnail from the server, if possible. Animated
  /// thumbnails typically use the content types `image/gif`, `image/png` (with APNG format),
  /// `image/apng`, and `image/webp` instead of the common static `image/png` or `image/jpeg`
  /// content types.
  ///
  /// When `true`, the server SHOULD return an animated thumbnail if possible and supported.
  /// When `false`, the server MUST NOT return an animated thumbnail. For example, returning a
  /// static `image/png` or `image/jpeg` thumbnail. When not provided, the server SHOULD NOT
  /// return an animated thumbnail.
  ///
  /// Servers SHOULD prefer to return `image/webp` thumbnails when supporting animation.
  ///
  /// When `true` and the media cannot be animated, such as in the case of a JPEG or PDF, the
  /// server SHOULD behave as though `animated` is `false`.
  @override
  Future<FileResponse> getContentThumbnail(
    String serverName,
    String mediaId,
    int width,
    int height, {
    Method? method,
    bool? allowRemote,
    int? timeoutMs,
    bool? allowRedirect,
    bool? animated,
  }) async {
    return (await authenticatedMediaSupported())
        ? getContentThumbnailAuthed(
            serverName,
            mediaId,
            width,
            height,
            method: method,
            timeoutMs: timeoutMs,
            animated: animated,
          )
        // ignore: deprecated_member_use_from_same_package
        : super.getContentThumbnail(
            serverName,
            mediaId,
            width,
            height,
            method: method,
            timeoutMs: timeoutMs,
            animated: animated,
          );
  }

  /// Get information about a URL for the client. Typically this is called when a
  /// client sees a URL in a message and wants to render a preview for the user.
  ///
  /// {{% boxes/note %}}
  /// Clients should consider avoiding this endpoint for URLs posted in encrypted
  /// rooms. Encrypted rooms often contain more sensitive information the users
  /// do not want to share with the homeserver, and this can mean that the URLs
  /// being shared should also not be shared with the homeserver.
  /// {{% /boxes/note %}}
  ///
  /// [url] The URL to get a preview of.
  ///
  /// [ts] The preferred point in time to return a preview for. The server may
  /// return a newer version if it does not have the requested version
  /// available.
  @override
  Future<PreviewForUrl> getUrlPreview(Uri url, {int? ts}) async {
    return (await authenticatedMediaSupported())
        ? getUrlPreviewAuthed(url, ts: ts)
        // ignore: deprecated_member_use_from_same_package
        : super.getUrlPreview(url, ts: ts);
  }

  /// Uploads a file into the Media Repository of the server and also caches it
  /// in the local database, if it is small enough.
  /// Returns the mxc url. Please note, that this does **not** encrypt
  /// the content. Use `Room.sendFileEvent()` for end to end encryption.
  @override
  Future<Uri> uploadContent(
    Uint8List file, {
    String? filename,
    String? contentType,
  }) async {
    final mediaConfig = await getConfig();
    final maxMediaSize = mediaConfig.mUploadSize;
    if (maxMediaSize != null && maxMediaSize < file.lengthInBytes) {
      throw FileTooBigMatrixException(file.lengthInBytes, maxMediaSize);
    }

    contentType ??= lookupMimeType(filename ?? '', headerBytes: file);
    final mxc = await super
        .uploadContent(file, filename: filename, contentType: contentType);

    final database = this.database;
    if (database != null && file.length <= database.maxFileSize) {
      await database.storeFile(
        mxc,
        file,
        DateTime.now().millisecondsSinceEpoch,
      );
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

  /// dumps the local database and exports it into a String.
  ///
  /// WARNING: never re-import the dump twice
  ///
  /// This can be useful to migrate a session from one device to a future one.
  Future<String?> exportDump() async {
    if (database != null) {
      await abortSync();
      await dispose(closeDatabase: false);

      final export = await database!.exportDump();

      await clear();
      return export;
    }
    return null;
  }

  /// imports a dumped session
  ///
  /// WARNING: never re-import the dump twice
  Future<bool> importDump(String export) async {
    try {
      // stopping sync loop and subscriptions while keeping DB open
      await dispose(closeDatabase: false);
    } catch (_) {
      // Client was probably not initialized yet.
    }

    _database ??= await databaseBuilder!.call(this);

    final success = await database!.importDump(export);

    if (success) {
      // closing including DB
      await dispose();

      try {
        bearerToken = null;

        await init(
          waitForFirstSync: false,
          waitUntilLoadCompletedLoaded: false,
        );
      } catch (e) {
        return false;
      }
    }
    return success;
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
    final pushrules = _accountData['m.push_rules']
        ?.content
        .tryGetMap<String, Object?>('global');
    return pushrules != null ? TryGetPushRule.tryFromJson(pushrules) : null;
  }

  /// Returns the device push rules for the logged in user.
  PushRuleSet? get devicePushRules {
    final pushrules = _accountData['m.push_rules']
        ?.content
        .tryGetMap<String, Object?>('device');
    return pushrules != null ? TryGetPushRule.tryFromJson(pushrules) : null;
  }

  static const Set<String> supportedVersions = {
    'v1.1',
    'v1.2',
    'v1.3',
    'v1.4',
    'v1.5',
    'v1.6',
    'v1.7',
    'v1.8',
    'v1.9',
    'v1.10',
    'v1.11',
    'v1.12',
    'v1.13',
  };

  static const List<String> supportedDirectEncryptionAlgorithms = [
    AlgorithmTypes.olmV1Curve25519AesSha2,
  ];
  static const List<String> supportedGroupEncryptionAlgorithms = [
    AlgorithmTypes.megolmV1AesSha2,
  ];
  static const int defaultThumbnailSize = 800;

  /// The newEvent signal is the most important signal in this concept. Every time
  /// the app receives a new synchronization, this event is called for every signal
  /// to update the GUI. For example, for a new message, it is called:
  /// onRoomEvent( "m.room.message", "!chat_id:server.com", "timeline", {sender: "@bob:server.com", body: "Hello world"} )
  // ignore: deprecated_member_use_from_same_package
  @Deprecated(
    'Use `onTimelineEvent`, `onHistoryEvent` or `onNotification` instead.',
  )
  final CachedStreamController<EventUpdate> onEvent = CachedStreamController();

  /// A stream of all incoming timeline events for all rooms **after**
  /// decryption. The events are coming in the same order as they come down from
  /// the sync.
  final CachedStreamController<Event> onTimelineEvent =
      CachedStreamController();

  /// A stream for all incoming historical timeline events **after** decryption
  /// triggered by a `Room.requestHistory()` call or a method which calls it.
  final CachedStreamController<Event> onHistoryEvent = CachedStreamController();

  /// A stream of incoming Events **after** decryption which **should** trigger
  /// a (local) notification. This includes timeline events but also
  /// invite states. Excluded events are those sent by the user themself or
  /// not matching the push rules.
  final CachedStreamController<Event> onNotification = CachedStreamController();

  /// The onToDeviceEvent is called when there comes a new to device event. It is
  /// already decrypted if necessary.
  final CachedStreamController<ToDeviceEvent> onToDeviceEvent =
      CachedStreamController();

  /// Tells you about to-device and room call specific events in sync
  final CachedStreamController<List<BasicEventWithSender>> onCallEvents =
      CachedStreamController();

  /// Called when the login state e.g. user gets logged out.
  final CachedStreamController<LoginState> onLoginStateChanged =
      CachedStreamController();

  /// Called when the local cache is reset
  final CachedStreamController<bool> onCacheCleared = CachedStreamController();

  /// Encryption errors are coming here.
  final CachedStreamController<SdkError> onEncryptionError =
      CachedStreamController();

  /// When a new sync response is coming in, this gives the complete payload.
  final CachedStreamController<SyncUpdate> onSync = CachedStreamController();

  /// This gives the current status of the synchronization
  final CachedStreamController<SyncStatusUpdate> onSyncStatus =
      CachedStreamController();

  /// Callback will be called on presences.
  @Deprecated(
    'Deprecated, use onPresenceChanged instead which has a timestamp.',
  )
  final CachedStreamController<Presence> onPresence = CachedStreamController();

  /// Callback will be called on presence updates.
  final CachedStreamController<CachedPresence> onPresenceChanged =
      CachedStreamController();

  /// Callback will be called on account data updates.
  @Deprecated('Use `client.onSync` instead')
  final CachedStreamController<BasicEvent> onAccountData =
      CachedStreamController();

  /// Will be called when another device is requesting session keys for a room.
  final CachedStreamController<RoomKeyRequest> onRoomKeyRequest =
      CachedStreamController();

  /// Will be called when another device is requesting verification with this device.
  final CachedStreamController<KeyVerification> onKeyVerificationRequest =
      CachedStreamController();

  /// When the library calls an endpoint that needs UIA the `UiaRequest` is passed down this stream.
  /// The client can open a UIA prompt based on this.
  final CachedStreamController<UiaRequest> onUiaRequest =
      CachedStreamController();

  @Deprecated('This is not in use anywhere anymore')
  final CachedStreamController<Event> onGroupMember = CachedStreamController();

  final CachedStreamController<String> onCancelSendEvent =
      CachedStreamController();

  /// When a state in a room has been updated this will return the room ID
  /// and the state event.
  final CachedStreamController<({String roomId, StrippedStateEvent state})>
      onRoomState = CachedStreamController();

  /// How long should the app wait until it retrys the synchronisation after
  /// an error?
  int syncErrorTimeoutSec = 3;

  bool _initLock = false;

  /// Fetches the corresponding Event object from a notification including a
  /// full Room object with the sender User object in it. Returns null if this
  /// push notification is not corresponding to an existing event.
  /// The client does **not** need to be initialized first. If it is not
  /// initialized, it will only fetch the necessary parts of the database. This
  /// should make it possible to run this parallel to another client with the
  /// same client name.
  /// This also checks if the given event has a readmarker and returns null
  /// in this case.
  Future<Event?> getEventByPushNotification(
    PushNotification notification, {
    bool storeInDatabase = true,
    Duration timeoutForServerRequests = const Duration(seconds: 8),
    bool returnNullIfSeen = true,
  }) async {
    // Get access token if necessary:
    final database = _database ??= await databaseBuilder?.call(this);
    if (!isLogged()) {
      if (database == null) {
        throw Exception(
          'Can not execute getEventByPushNotification() without a database',
        );
      }
      final clientInfoMap = await database.getClient(clientName);
      final token = clientInfoMap?.tryGet<String>('token');
      if (token == null) {
        throw Exception('Client is not logged in.');
      }
      accessToken = token;
    }

    await ensureNotSoftLoggedOut();

    // Check if the notification contains an event at all:
    final eventId = notification.eventId;
    final roomId = notification.roomId;
    if (eventId == null || roomId == null) return null;

    // Create the room object:
    final room = getRoomById(roomId) ??
        await database?.getSingleRoom(this, roomId) ??
        Room(
          id: roomId,
          client: this,
        );
    final roomName = notification.roomName;
    final roomAlias = notification.roomAlias;
    if (roomName != null) {
      room.setState(
        Event(
          eventId: 'TEMP',
          stateKey: '',
          type: EventTypes.RoomName,
          content: {'name': roomName},
          room: room,
          senderId: 'UNKNOWN',
          originServerTs: DateTime.now(),
        ),
      );
    }
    if (roomAlias != null) {
      room.setState(
        Event(
          eventId: 'TEMP',
          stateKey: '',
          type: EventTypes.RoomCanonicalAlias,
          content: {'alias': roomAlias},
          room: room,
          senderId: 'UNKNOWN',
          originServerTs: DateTime.now(),
        ),
      );
    }

    // Load the event from the notification or from the database or from server:
    MatrixEvent? matrixEvent;
    final content = notification.content;
    final sender = notification.sender;
    final type = notification.type;
    if (content != null && sender != null && type != null) {
      matrixEvent = MatrixEvent(
        content: content,
        senderId: sender,
        type: type,
        originServerTs: DateTime.now(),
        eventId: eventId,
        roomId: roomId,
      );
    }
    matrixEvent ??= await database
        ?.getEventById(eventId, room)
        .timeout(timeoutForServerRequests);

    try {
      matrixEvent ??= await getOneRoomEvent(roomId, eventId)
          .timeout(timeoutForServerRequests);
    } on MatrixException catch (_) {
      // No access to the MatrixEvent. Search in /notifications
      final notificationsResponse = await getNotifications();
      matrixEvent ??= notificationsResponse.notifications
          .firstWhereOrNull(
            (notification) =>
                notification.roomId == roomId &&
                notification.event.eventId == eventId,
          )
          ?.event;
    }

    if (matrixEvent == null) {
      throw Exception('Unable to find event for this push notification!');
    }

    // If the event was already in database, check if it has a read marker
    // before displaying it.
    if (returnNullIfSeen) {
      if (room.fullyRead == matrixEvent.eventId) {
        return null;
      }
      final readMarkerEvent = await database
          ?.getEventById(room.fullyRead, room)
          .timeout(timeoutForServerRequests);
      if (readMarkerEvent != null &&
          readMarkerEvent.originServerTs.isAfter(
            matrixEvent.originServerTs
              // As origin server timestamps are not always correct data in
              // a federated environment, we add 10 minutes to the calculation
              // to reduce the possibility that an event is marked as read which
              // isn't.
              ..add(Duration(minutes: 10)),
          )) {
        return null;
      }
    }

    // Load the sender of this event
    try {
      await room
          .requestUser(matrixEvent.senderId)
          .timeout(timeoutForServerRequests);
    } catch (e, s) {
      Logs().w('Unable to request user for push helper', e, s);
      final senderDisplayName = notification.senderDisplayName;
      if (senderDisplayName != null && sender != null) {
        room.setState(User(sender, displayName: senderDisplayName, room: room));
      }
    }

    // Create Event object and decrypt if necessary
    var event = Event.fromMatrixEvent(
      matrixEvent,
      room,
      status: EventStatus.sent,
    );

    final encryption = this.encryption;
    if (event.type == EventTypes.Encrypted && encryption != null) {
      var decrypted = await encryption.decryptRoomEvent(event);
      if (decrypted.messageType == MessageTypes.BadEncrypted &&
          prevBatch != null) {
        await oneShotSync();
        decrypted = await encryption.decryptRoomEvent(event);
      }
      event = decrypted;
    }

    if (storeInDatabase) {
      await database?.transaction(() async {
        await database.storeEventUpdate(
          roomId,
          event,
          EventUpdateType.timeline,
          this,
        );
      });
    }

    return event;
  }

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
  /// up. You can then wait for `roomsLoading`, `_accountDataLoading` and
  /// `userDeviceKeysLoading` where it is necessary.
  Future<void> init({
    String? newToken,
    DateTime? newTokenExpiresAt,
    String? newRefreshToken,
    Uri? newHomeserver,
    String? newUserID,
    String? newDeviceName,
    String? newDeviceID,
    String? newOlmAccount,
    bool waitForFirstSync = true,
    bool waitUntilLoadCompletedLoaded = true,

    /// Will be called if the app performs a migration task from the [legacyDatabaseBuilder]
    @Deprecated('Use onInitStateChanged and listen to `InitState.migration`.')
    void Function()? onMigration,

    /// To track what actually happens you can set a callback here.
    void Function(InitState)? onInitStateChanged,
  }) async {
    if ((newToken != null ||
            newUserID != null ||
            newDeviceID != null ||
            newDeviceName != null) &&
        (newToken == null ||
            newUserID == null ||
            newDeviceID == null ||
            newDeviceName == null)) {
      throw ClientInitPreconditionError(
        'If one of [newToken, newUserID, newDeviceID, newDeviceName] is set then all of them must be set!',
      );
    }

    if (_initLock) {
      throw ClientInitPreconditionError(
        '[init()] has been called multiple times!',
      );
    }
    _initLock = true;
    String? olmAccount;
    String? accessToken;
    String? userID;
    try {
      onInitStateChanged?.call(InitState.initializing);
      Logs().i('Initialize client $clientName');
      if (onLoginStateChanged.value == LoginState.loggedIn) {
        throw ClientInitPreconditionError(
          'User is already logged in! Call [logout()] first!',
        );
      }

      final databaseBuilder = this.databaseBuilder;
      if (databaseBuilder != null) {
        _database ??= await runBenchmarked<DatabaseApi>(
          'Build database',
          () async => await databaseBuilder(this),
        );
      }

      _groupCallSessionId = randomAlpha(12);

      /// while I would like to move these to a onLoginStateChanged stream listener
      /// that might be too much overhead and you don't have any use of these
      /// when you are logged out anyway. So we just invalidate them on next login
      _serverConfigCache.invalidate();
      _versionsCache.invalidate();

      final account = await this.database?.getClient(clientName);
      newRefreshToken ??= account?.tryGet<String>('refresh_token');
      // can have discovery_information so make sure it also has the proper
      // account creds
      if (account != null &&
          account['homeserver_url'] != null &&
          account['user_id'] != null &&
          account['token'] != null) {
        _id = account['client_id'];
        homeserver = Uri.parse(account['homeserver_url']);
        accessToken = this.accessToken = account['token'];
        final tokenExpiresAtMs =
            int.tryParse(account.tryGet<String>('token_expires_at') ?? '');
        _accessTokenExpiresAt = tokenExpiresAtMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(tokenExpiresAtMs);
        userID = _userID = account['user_id'];
        _deviceID = account['device_id'];
        _deviceName = account['device_name'];
        _syncFilterId = account['sync_filter_id'];
        _prevBatch = account['prev_batch'];
        olmAccount = account['olm_account'];
      }
      if (newToken != null) {
        accessToken = this.accessToken = newToken;
        _accessTokenExpiresAt = newTokenExpiresAt;
        homeserver = newHomeserver;
        userID = _userID = newUserID;
        _deviceID = newDeviceID;
        _deviceName = newDeviceName;
        olmAccount = newOlmAccount;
      } else {
        accessToken = this.accessToken = newToken ?? accessToken;
        _accessTokenExpiresAt = newTokenExpiresAt ?? accessTokenExpiresAt;
        homeserver = newHomeserver ?? homeserver;
        userID = _userID = newUserID ?? userID;
        _deviceID = newDeviceID ?? _deviceID;
        _deviceName = newDeviceName ?? _deviceName;
        olmAccount = newOlmAccount ?? olmAccount;
      }

      // If we are refreshing the session, we are done here:
      if (onLoginStateChanged.value == LoginState.softLoggedOut) {
        if (newRefreshToken != null && accessToken != null && userID != null) {
          // Store the new tokens:
          await _database?.updateClient(
            homeserver.toString(),
            accessToken,
            accessTokenExpiresAt,
            newRefreshToken,
            userID,
            _deviceID,
            _deviceName,
            prevBatch,
            encryption?.pickledOlmAccount,
          );
        }
        onInitStateChanged?.call(InitState.finished);
        onLoginStateChanged.add(LoginState.loggedIn);
        return;
      }

      if (accessToken == null || homeserver == null || userID == null) {
        if (legacyDatabaseBuilder != null) {
          await _migrateFromLegacyDatabase(
            onInitStateChanged: onInitStateChanged,
            onMigration: onMigration,
          );
          if (isLogged()) {
            onInitStateChanged?.call(InitState.finished);
            return;
          }
        }
        // we aren't logged in
        await encryption?.dispose();
        _encryption = null;
        onLoginStateChanged.add(LoginState.loggedOut);
        Logs().i('User is not logged in.');
        _initLock = false;
        onInitStateChanged?.call(InitState.finished);
        return;
      }

      await encryption?.dispose();
      try {
        // make sure to throw an exception if libolm doesn't exist
        await olm.init();
        olm.get_library_version();
        _encryption = Encryption(client: this);
      } catch (e) {
        Logs().e('Error initializing encryption $e');
        await encryption?.dispose();
        _encryption = null;
      }
      onInitStateChanged?.call(InitState.settingUpEncryption);
      await encryption?.init(olmAccount);

      final database = this.database;
      if (database != null) {
        if (id != null) {
          await database.updateClient(
            homeserver.toString(),
            accessToken,
            accessTokenExpiresAt,
            newRefreshToken,
            userID,
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
            accessTokenExpiresAt,
            newRefreshToken,
            userID,
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
        _accountDataLoading = database.getAccountData().then((data) {
          _accountData = data;
          _updatePushrules();
        });
        _discoveryDataLoading = database.getWellKnown().then((data) {
          _wellKnown = data;
        });
        // ignore: deprecated_member_use_from_same_package
        presences.clear();
        if (waitUntilLoadCompletedLoaded) {
          onInitStateChanged?.call(InitState.loadingData);
          await userDeviceKeysLoading;
          await roomsLoading;
          await _accountDataLoading;
          await _discoveryDataLoading;
        }
      }
      _initLock = false;
      onLoginStateChanged.add(LoginState.loggedIn);
      Logs().i(
        'Successfully connected as ${userID.localpart} with ${homeserver.toString()}',
      );

      /// Timeout of 0, so that we don't see a spinner for 30 seconds.
      firstSyncReceived = _sync(timeout: Duration.zero);
      if (waitForFirstSync) {
        onInitStateChanged?.call(InitState.waitingForFirstSync);
        await firstSyncReceived;
      }
      onInitStateChanged?.call(InitState.finished);
      return;
    } on ClientInitPreconditionError {
      onInitStateChanged?.call(InitState.error);
      rethrow;
    } catch (e, s) {
      Logs().wtf('Client initialization failed', e, s);
      onLoginStateChanged.addError(e, s);
      onInitStateChanged?.call(InitState.error);
      final clientInitException = ClientInitException(
        e,
        homeserver: homeserver,
        accessToken: accessToken,
        userId: userID,
        deviceId: deviceID,
        deviceName: deviceName,
        olmAccount: olmAccount,
      );
      await clear();
      throw clientInitException;
    } finally {
      _initLock = false;
    }
  }

  /// Used for testing only
  void setUserId(String s) {
    _userID = s;
  }

  /// Resets all settings and stops the synchronisation.
  Future<void> clear() async {
    Logs().outputEvents.clear();
    DatabaseApi? legacyDatabase;
    if (legacyDatabaseBuilder != null) {
      // If there was data in the legacy db, it will never let the SDK
      // completely log out as we migrate data from it, everytime we `init`
      legacyDatabase = await legacyDatabaseBuilder?.call(this);
    }
    try {
      await abortSync();
      await database?.clear();
      await legacyDatabase?.clear();
      _backgroundSync = true;
    } catch (e, s) {
      Logs().e('Unable to clear database', e, s);
    } finally {
      await database?.delete();
      await legacyDatabase?.delete();
      _database = null;
    }

    _id = accessToken = _syncFilterId =
        homeserver = _userID = _deviceID = _deviceName = _prevBatch = null;
    _rooms = [];
    _eventsPendingDecryption.clear();
    await encryption?.dispose();
    _encryption = null;
    onLoginStateChanged.add(LoginState.loggedOut);
  }

  bool _backgroundSync = true;
  Future<void>? _currentSync;
  Future<void> _retryDelay = Future.value();

  bool get syncPending => _currentSync != null;

  /// Controls the background sync (automatically looping forever if turned on).
  /// If you use soft logout, you need to manually call
  /// `ensureNotSoftLoggedOut()` before doing any API request after setting
  /// the background sync to false, as the soft logout is handeld automatically
  /// in the sync loop.
  set backgroundSync(bool enabled) {
    _backgroundSync = enabled;
    if (_backgroundSync) {
      runInRoot(() async => _sync());
    }
  }

  /// Immediately start a sync and wait for completion.
  /// If there is an active sync already, wait for the active sync instead.
  Future<void> oneShotSync() {
    return _sync();
  }

  /// Pass a timeout to set how long the server waits before sending an empty response.
  /// (Corresponds to the timeout param on the /sync request.)
  Future<void> _sync({Duration? timeout}) {
    final currentSync =
        _currentSync ??= _innerSync(timeout: timeout).whenComplete(() {
      _currentSync = null;
      if (_backgroundSync && isLogged() && !_disposed) {
        _sync();
      }
    });
    return currentSync;
  }

  /// Presence that is set on sync.
  PresenceType? syncPresence;

  Future<void> _checkSyncFilter() async {
    final userID = this.userID;
    if (syncFilterId == null && userID != null) {
      final syncFilterId =
          _syncFilterId = await defineFilter(userID, syncFilter);
      await database?.storeSyncFilterId(syncFilterId);
    }
    return;
  }

  Future<void>? _handleSoftLogoutFuture;

  Future<void> _handleSoftLogout() async {
    final onSoftLogout = this.onSoftLogout;
    if (onSoftLogout == null) {
      await logout();
      return;
    }

    _handleSoftLogoutFuture ??= () async {
      onLoginStateChanged.add(LoginState.softLoggedOut);
      try {
        await onSoftLogout(this);
        onLoginStateChanged.add(LoginState.loggedIn);
      } catch (e, s) {
        Logs().w('Unable to refresh session after soft logout', e, s);
        await logout();
        rethrow;
      }
    }();
    await _handleSoftLogoutFuture;
    _handleSoftLogoutFuture = null;
  }

  /// Checks if the token expires in under [expiresIn] time and calls the
  /// given `onSoftLogout()` if so. You have to provide `onSoftLogout` in the
  /// Client constructor. Otherwise this will do nothing.
  Future<void> ensureNotSoftLoggedOut([
    Duration expiresIn = const Duration(minutes: 1),
  ]) async {
    final tokenExpiresAt = accessTokenExpiresAt;
    if (onSoftLogout != null &&
        tokenExpiresAt != null &&
        tokenExpiresAt.difference(DateTime.now()) <= expiresIn) {
      await _handleSoftLogout();
    }
  }

  /// Pass a timeout to set how long the server waits before sending an empty response.
  /// (Corresponds to the timeout param on the /sync request.)
  Future<void> _innerSync({Duration? timeout}) async {
    await _retryDelay;
    _retryDelay = Future.delayed(Duration(seconds: syncErrorTimeoutSec));
    if (!isLogged() || _disposed || _aborted) return;
    try {
      if (_initLock) {
        Logs().d('Running sync while init isn\'t done yet, dropping request');
        return;
      }
      Object? syncError;

      // The timeout we send to the server for the sync loop. It says to the
      // server that we want to receive an empty sync response after this
      // amount of time if nothing happens.
      if (prevBatch != null) timeout ??= const Duration(seconds: 30);

      await ensureNotSoftLoggedOut(
        timeout == null ? const Duration(minutes: 1) : (timeout * 2),
      );

      await _checkSyncFilter();

      final syncRequest = sync(
        filter: syncFilterId,
        since: prevBatch,
        timeout: timeout?.inMilliseconds,
        setPresence: syncPresence,
      ).then((v) => Future<SyncUpdate?>.value(v)).catchError((e) {
        if (e is MatrixException) {
          syncError = e;
        } else {
          syncError = SyncConnectionException(e);
        }
        return null;
      });
      _currentSyncId = syncRequest.hashCode;
      onSyncStatus.add(SyncStatusUpdate(SyncStatus.waitingForResponse));

      // The timeout for the response from the server. If we do not set a sync
      // timeout (for initial sync) we give the server a longer time to
      // responde.
      final responseTimeout =
          timeout == null ? null : timeout + const Duration(seconds: 10);

      final syncResp = responseTimeout == null
          ? await syncRequest
          : await syncRequest.timeout(responseTimeout);

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
        await _accountDataLoading;
        _currentTransaction = database.transaction(() async {
          await _handleSync(syncResp, direction: Direction.f);
          if (prevBatch != syncResp.nextBatch) {
            await database.storePrevBatch(syncResp.nextBatch);
          }
        });
        await runBenchmarked(
          'Process sync',
          () async => await _currentTransaction,
          syncResp.itemCount,
        );
      } else {
        await _handleSync(syncResp, direction: Direction.f);
      }
      if (_disposed || _aborted) return;
      _prevBatch = syncResp.nextBatch;
      onSyncStatus.add(SyncStatusUpdate(SyncStatus.cleaningUp));
      // ignore: unawaited_futures
      database?.deleteOldFiles(
        DateTime.now().subtract(Duration(days: 30)).millisecondsSinceEpoch,
      );
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
      onSyncStatus.add(
        SyncStatusUpdate(
          SyncStatus.error,
          error: SdkError(exception: e, stackTrace: s),
        ),
      );
      if (e.error == MatrixError.M_UNKNOWN_TOKEN) {
        if (e.raw.tryGet<bool>('soft_logout') == true) {
          Logs().w(
            'The user has been soft logged out! Calling client.onSoftLogout() if present.',
          );
          await _handleSoftLogout();
        } else {
          Logs().w('The user has been logged out!');
          await clear();
        }
      }
    } on SyncConnectionException catch (e, s) {
      Logs().w('Syncloop failed: Client has not connection to the server');
      onSyncStatus.add(
        SyncStatusUpdate(
          SyncStatus.error,
          error: SdkError(exception: e, stackTrace: s),
        ),
      );
    } catch (e, s) {
      if (!isLogged() || _disposed || _aborted) return;
      Logs().e('Error during processing events', e, s);
      onSyncStatus.add(
        SyncStatusUpdate(
          SyncStatus.error,
          error: SdkError(
            exception: e is Exception ? e : Exception(e),
            stackTrace: s,
          ),
        ),
      );
    }
  }

  /// Use this method only for testing utilities!
  Future<void> handleSync(SyncUpdate sync, {Direction? direction}) async {
    // ensure we don't upload keys because someone forgot to set a key count
    sync.deviceOneTimeKeysCount ??= {
      'signed_curve25519': encryption?.olmManager.maxNumberOfOneTimeKeys ?? 100,
    };
    await _handleSync(sync, direction: direction);
  }

  Future<void> _handleSync(SyncUpdate sync, {Direction? direction}) async {
    final syncToDevice = sync.toDevice;
    if (syncToDevice != null) {
      await _handleToDeviceEvents(syncToDevice);
    }

    if (sync.rooms != null) {
      final join = sync.rooms?.join;
      if (join != null) {
        await _handleRooms(join, direction: direction);
      }
      // We need to handle leave before invite. If you decline an invite and
      // then get another invite to the same room, Synapse will include the
      // room both in invite and leave. If you get an invite and then leave, it
      // will only be included in leave.
      final leave = sync.rooms?.leave;
      if (leave != null) {
        await _handleRooms(leave, direction: direction);
      }
      final invite = sync.rooms?.invite;
      if (invite != null) {
        await _handleRooms(invite, direction: direction);
      }
    }
    for (final newPresence in sync.presence ?? <Presence>[]) {
      final cachedPresence = CachedPresence.fromMatrixEvent(newPresence);
      // ignore: deprecated_member_use_from_same_package
      presences[newPresence.senderId] = cachedPresence;
      // ignore: deprecated_member_use_from_same_package
      onPresence.add(newPresence);
      onPresenceChanged.add(cachedPresence);
      await database?.storePresence(newPresence.senderId, cachedPresence);
    }
    for (final newAccountData in sync.accountData ?? <BasicEvent>[]) {
      await database?.storeAccountData(
        newAccountData.type,
        newAccountData.content,
      );
      accountData[newAccountData.type] = newAccountData;
      // ignore: deprecated_member_use_from_same_package
      onAccountData.add(newAccountData);

      if (newAccountData.type == EventTypes.PushRules) {
        _updatePushrules();
      }
    }

    final syncDeviceLists = sync.deviceLists;
    if (syncDeviceLists != null) {
      await _handleDeviceListsEvents(syncDeviceLists);
    }
    if (encryptionEnabled) {
      encryption?.handleDeviceOneTimeKeysCount(
        sync.deviceOneTimeKeysCount,
        sync.deviceUnusedFallbackKeyTypes,
      );
    }
    _sortRooms();
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
    final Map<String, List<String>> roomsWithNewKeyToSessionId = {};
    final List<ToDeviceEvent> callToDeviceEvents = [];
    for (final event in events) {
      var toDeviceEvent = ToDeviceEvent.fromJson(event.toJson());
      Logs().v('Got to_device event of type ${toDeviceEvent.type}');
      if (encryptionEnabled) {
        if (toDeviceEvent.type == EventTypes.Encrypted) {
          toDeviceEvent = await encryption!.decryptToDeviceEvent(toDeviceEvent);
          Logs().v('Decrypted type is: ${toDeviceEvent.type}');

          /// collect new keys so that we can find those events in the decryption queue
          if (toDeviceEvent.type == EventTypes.ForwardedRoomKey ||
              toDeviceEvent.type == EventTypes.RoomKey) {
            final roomId = event.content['room_id'];
            final sessionId = event.content['session_id'];
            if (roomId is String && sessionId is String) {
              (roomsWithNewKeyToSessionId[roomId] ??= []).add(sessionId);
            }
          }
        }
        await encryption?.handleToDeviceEvent(toDeviceEvent);
      }
      if (toDeviceEvent.type.startsWith(CallConstants.callEventsRegxp)) {
        callToDeviceEvents.add(toDeviceEvent);
      }
      onToDeviceEvent.add(toDeviceEvent);
    }

    if (callToDeviceEvents.isNotEmpty) {
      onCallEvents.add(callToDeviceEvents);
    }

    // emit updates for all events in the queue
    for (final entry in roomsWithNewKeyToSessionId.entries) {
      final roomId = entry.key;
      final sessionIds = entry.value;

      final room = getRoomById(roomId);
      if (room != null) {
        final events = <Event>[];
        for (final event in _eventsPendingDecryption) {
          if (event.event.room.id != roomId) continue;
          if (!sessionIds.contains(
            event.event.content.tryGet<String>('session_id'),
          )) {
            continue;
          }

          final decryptedEvent =
              await encryption!.decryptRoomEvent(event.event);
          if (decryptedEvent.type != EventTypes.Encrypted) {
            events.add(decryptedEvent);
          }
        }

        await _handleRoomEvents(
          room,
          events,
          EventUpdateType.decryptedTimelineQueue,
        );

        _eventsPendingDecryption.removeWhere(
          (e) => events.any(
            (decryptedEvent) =>
                decryptedEvent.content['event_id'] ==
                e.event.content['event_id'],
          ),
        );
      }
    }
    _eventsPendingDecryption.removeWhere((e) => e.timedOut);
  }

  Future<void> _handleRooms(
    Map<String, SyncRoomUpdate> rooms, {
    Direction? direction,
  }) async {
    var handledRooms = 0;
    for (final entry in rooms.entries) {
      onSyncStatus.add(
        SyncStatusUpdate(
          SyncStatus.processing,
          progress: ++handledRooms / rooms.length,
        ),
      );
      final id = entry.key;
      final syncRoomUpdate = entry.value;

      // Is the timeline limited? Then all previous messages should be
      // removed from the database!
      if (syncRoomUpdate is JoinedRoomUpdate &&
          syncRoomUpdate.timeline?.limited == true) {
        await database?.deleteTimelineForRoom(id);
      }
      final room = await _updateRoomsByRoomUpdate(id, syncRoomUpdate);

      final timelineUpdateType = direction != null
          ? (direction == Direction.b
              ? EventUpdateType.history
              : EventUpdateType.timeline)
          : EventUpdateType.timeline;

      /// Handle now all room events and save them in the database
      if (syncRoomUpdate is JoinedRoomUpdate) {
        final state = syncRoomUpdate.state;

        // If we are receiving states when fetching history we need to check if
        // we are not overwriting a newer state.
        if (direction == Direction.b) {
          await room.postLoad();
          state?.removeWhere((state) {
            final existingState =
                room.getState(state.type, state.stateKey ?? '');
            if (existingState == null) return false;
            if (existingState is User) {
              return existingState.originServerTs
                      ?.isAfter(state.originServerTs) ??
                  true;
            }
            if (existingState is MatrixEvent) {
              return existingState.originServerTs.isAfter(state.originServerTs);
            }
            return true;
          });
        }

        if (state != null && state.isNotEmpty) {
          await _handleRoomEvents(
            room,
            state,
            EventUpdateType.state,
          );
        }

        final timelineEvents = syncRoomUpdate.timeline?.events;
        if (timelineEvents != null && timelineEvents.isNotEmpty) {
          await _handleRoomEvents(room, timelineEvents, timelineUpdateType);
        }

        final ephemeral = syncRoomUpdate.ephemeral;
        if (ephemeral != null && ephemeral.isNotEmpty) {
          // TODO: This method seems to be comperatively slow for some updates
          await _handleEphemerals(
            room,
            ephemeral,
          );
        }

        final accountData = syncRoomUpdate.accountData;
        if (accountData != null && accountData.isNotEmpty) {
          for (final event in accountData) {
            await database?.storeRoomAccountData(room.id, event);
            room.roomAccountData[event.type] = event;
          }
        }
      }

      if (syncRoomUpdate is LeftRoomUpdate) {
        final timelineEvents = syncRoomUpdate.timeline?.events;
        if (timelineEvents != null && timelineEvents.isNotEmpty) {
          await _handleRoomEvents(
            room,
            timelineEvents,
            timelineUpdateType,
            store: false,
          );
        }
        final accountData = syncRoomUpdate.accountData;
        if (accountData != null && accountData.isNotEmpty) {
          for (final event in accountData) {
            room.roomAccountData[event.type] = event;
          }
        }
        final state = syncRoomUpdate.state;
        if (state != null && state.isNotEmpty) {
          await _handleRoomEvents(
            room,
            state,
            EventUpdateType.state,
            store: false,
          );
        }
      }

      if (syncRoomUpdate is InvitedRoomUpdate) {
        final state = syncRoomUpdate.inviteState;
        if (state != null && state.isNotEmpty) {
          await _handleRoomEvents(room, state, EventUpdateType.inviteState);
        }
      }
      await database?.storeRoomUpdate(id, syncRoomUpdate, room.lastEvent, this);
    }
  }

  Future<void> _handleEphemerals(Room room, List<BasicEvent> events) async {
    final List<ReceiptEventContent> receipts = [];

    for (final event in events) {
      room.setEphemeral(event);

      // Receipt events are deltas between two states. We will create a
      // fake room account data event for this and store the difference
      // there.
      if (event.type != 'm.receipt') continue;

      receipts.add(ReceiptEventContent.fromJson(event.content));
    }

    if (receipts.isNotEmpty) {
      final receiptStateContent = room.receiptState;

      for (final e in receipts) {
        await receiptStateContent.update(e, room);
      }

      final event = BasicEvent(
        type: LatestReceiptState.eventType,
        content: receiptStateContent.toJson(),
      );
      await database?.storeRoomAccountData(room.id, event);
      room.roomAccountData[event.type] = event;
    }
  }

  /// Stores event that came down /sync but didn't get decrypted because of missing keys yet.
  final List<_EventPendingDecryption> _eventsPendingDecryption = [];

  Future<void> _handleRoomEvents(
    Room room,
    List<StrippedStateEvent> events,
    EventUpdateType type, {
    bool store = true,
  }) async {
    // Calling events can be omitted if they are outdated from the same sync. So
    // we collect them first before we handle them.
    final callEvents = <Event>[];

    for (var event in events) {
      // The client must ignore any new m.room.encryption event to prevent
      // man-in-the-middle attacks!
      if ((event.type == EventTypes.Encryption &&
          room.encrypted &&
          event.content.tryGet<String>('algorithm') !=
              room
                  .getState(EventTypes.Encryption)
                  ?.content
                  .tryGet<String>('algorithm'))) {
        continue;
      }

      if (event is MatrixEvent &&
          event.type == EventTypes.Encrypted &&
          encryptionEnabled) {
        event = await encryption!.decryptRoomEvent(
          Event.fromMatrixEvent(event, room),
          updateType: type,
        );

        if (event.type == EventTypes.Encrypted) {
          // if the event failed to decrypt, add it to the queue
          _eventsPendingDecryption.add(
            _EventPendingDecryption(Event.fromMatrixEvent(event, room)),
          );
        }
      }

      // Any kind of member change? We should invalidate the profile then:
      if (event.type == EventTypes.RoomMember) {
        final userId = event.stateKey;
        if (userId != null) {
          // We do not re-request the profile here as this would lead to
          // an unknown amount of network requests as we never know how many
          // member change events can come down in a single sync update.
          await database?.markUserProfileAsOutdated(userId);
          onUserProfileUpdate.add(userId);
        }
      }

      if (event.type == EventTypes.Message &&
          !room.isDirectChat &&
          database != null &&
          event is MatrixEvent &&
          room.getState(EventTypes.RoomMember, event.senderId) == null) {
        // In order to correctly render room list previews we need to fetch the member from the database
        final user = await database?.getUser(event.senderId, room);
        if (user != null) {
          room.setState(user);
        }
      }
      _updateRoomsByEventUpdate(room, event, type);
      if (store) {
        await database?.storeEventUpdate(room.id, event, type, this);
      }
      if (event is MatrixEvent && encryptionEnabled) {
        await encryption?.handleEventUpdate(
          Event.fromMatrixEvent(event, room),
          type,
        );
      }

      // ignore: deprecated_member_use_from_same_package
      onEvent.add(
        // ignore: deprecated_member_use_from_same_package
        EventUpdate(
          roomID: room.id,
          type: type,
          content: event.toJson(),
        ),
      );
      if (event is MatrixEvent) {
        final timelineEvent = Event.fromMatrixEvent(event, room);
        switch (type) {
          case EventUpdateType.timeline:
            onTimelineEvent.add(timelineEvent);
            if (prevBatch != null &&
                timelineEvent.senderId != userID &&
                room.notificationCount > 0 &&
                pushruleEvaluator.match(timelineEvent).notify) {
              onNotification.add(timelineEvent);
            }
            break;
          case EventUpdateType.history:
            onHistoryEvent.add(timelineEvent);
            break;
          default:
            break;
        }
      }

      // Trigger local notification for a new invite:
      if (prevBatch != null &&
          type == EventUpdateType.inviteState &&
          event.type == EventTypes.RoomMember &&
          event.stateKey == userID) {
        onNotification.add(
          Event(
            type: event.type,
            eventId: 'invite_for_${room.id}',
            senderId: event.senderId,
            originServerTs: DateTime.now(),
            stateKey: event.stateKey,
            content: event.content,
            room: room,
          ),
        );
      }

      if (prevBatch != null &&
          (type == EventUpdateType.timeline ||
              type == EventUpdateType.decryptedTimelineQueue)) {
        if (event is MatrixEvent &&
            (event.type.startsWith(CallConstants.callEventsRegxp))) {
          final callEvent = Event.fromMatrixEvent(event, room);
          callEvents.add(callEvent);
        }
      }
    }
    if (callEvents.isNotEmpty) {
      onCallEvents.add(callEvents);
    }
  }

  /// stores when we last checked for stale calls
  DateTime lastStaleCallRun = DateTime(0);

  Future<Room> _updateRoomsByRoomUpdate(
    String roomId,
    SyncRoomUpdate chatUpdate,
  ) async {
    // Update the chat list item.
    // Search the room in the rooms
    final roomIndex = rooms.indexWhere((r) => r.id == roomId);
    final found = roomIndex != -1;
    final membership = chatUpdate is LeftRoomUpdate
        ? Membership.leave
        : chatUpdate is InvitedRoomUpdate
            ? Membership.invite
            : Membership.join;

    final room = found
        ? rooms[roomIndex]
        : (chatUpdate is JoinedRoomUpdate
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
            : Room(id: roomId, membership: membership, client: this));

    // Does the chat already exist in the list rooms?
    if (!found && membership != Membership.leave) {
      // Check if the room is not in the rooms in the invited list
      if (_archivedRooms.isNotEmpty) {
        _archivedRooms.removeWhere((archive) => archive.room.id == roomId);
      }
      final position = membership == Membership.invite ? 0 : rooms.length;
      // Add the new chat to the list
      rooms.insert(position, room);
    }
    // If the membership is "leave" then remove the item and stop here
    else if (found && membership == Membership.leave) {
      rooms.removeAt(roomIndex);

      // in order to keep the archive in sync, add left room to archive
      if (chatUpdate is LeftRoomUpdate) {
        await _storeArchivedRoom(room.id, chatUpdate, leftRoom: room);
      }
    }
    // Update notification, highlight count and/or additional information
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
      // ignore: deprecated_member_use_from_same_package
      rooms[roomIndex].onUpdate.add(rooms[roomIndex].id);
      if ((chatUpdate.timeline?.limited ?? false) &&
          requestHistoryOnLimitedTimeline) {
        Logs().v(
          'Limited timeline for ${rooms[roomIndex].id} request history now',
        );
        runInRoot(rooms[roomIndex].requestHistory);
      }
    }
    return room;
  }

  void _updateRoomsByEventUpdate(
    Room room,
    StrippedStateEvent eventUpdate,
    EventUpdateType type,
  ) {
    if (type == EventUpdateType.history) return;

    switch (type) {
      case EventUpdateType.inviteState:
        room.setState(eventUpdate);
        break;
      case EventUpdateType.state:
      case EventUpdateType.timeline:
        if (eventUpdate is! MatrixEvent) {
          Logs().wtf(
            'Passed in a ${eventUpdate.runtimeType} with $type to _updateRoomsByEventUpdate(). This should never happen!',
          );
          assert(eventUpdate is! MatrixEvent);
          return;
        }
        final event = Event.fromMatrixEvent(eventUpdate, room);

        // Update the room state:
        if (event.stateKey != null &&
            (!room.partial || importantStateEvents.contains(event.type))) {
          room.setState(event);
        }
        if (type != EventUpdateType.timeline) break;

        // If last event is null or not a valid room preview event anyway,
        // just use this:
        if (room.lastEvent == null) {
          room.lastEvent = event;
          break;
        }

        // Is this event redacting the last event?
        if (event.type == EventTypes.Redaction &&
            ({
              room.lastEvent?.eventId,
              room.lastEvent?.relationshipEventId,
            }.contains(
              event.redacts ?? event.content.tryGet<String>('redacts'),
            ))) {
          room.lastEvent?.setRedactionEvent(event);
          break;
        }

        // Is this event an edit of the last event? Otherwise ignore it.
        if (event.relationshipType == RelationshipTypes.edit) {
          if (event.relationshipEventId == room.lastEvent?.eventId ||
              (room.lastEvent?.relationshipType == RelationshipTypes.edit &&
                  event.relationshipEventId ==
                      room.lastEvent?.relationshipEventId)) {
            room.lastEvent = event;
          }
          break;
        }

        // Is this event of an important type for the last event?
        if (!roomPreviewLastEvents.contains(event.type)) break;

        // Event is a valid new lastEvent:
        room.lastEvent = event;

        break;
      case EventUpdateType.history:
      case EventUpdateType.decryptedTimelineQueue:
        break;
    }
    // ignore: deprecated_member_use_from_same_package
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
  RoomSorter get sortRoomsBy => (a, b) {
        if (pinInvitedRooms &&
            a.membership != b.membership &&
            [a.membership, b.membership].any((m) => m == Membership.invite)) {
          return a.membership == Membership.invite ? -1 : 1;
        } else if (a.isFavourite != b.isFavourite) {
          return a.isFavourite ? -1 : 1;
        } else if (pinUnreadRooms &&
            a.notificationCount != b.notificationCount) {
          return b.notificationCount.compareTo(a.notificationCount);
        } else {
          return b.latestEventReceivedTime.millisecondsSinceEpoch
              .compareTo(a.latestEventReceivedTime.millisecondsSinceEpoch);
        }
      };

  void _sortRooms() {
    if (_sortLock || rooms.length < 2) return;
    _sortLock = true;
    rooms.sort(sortRoomsBy);
    _sortLock = false;
  }

  Future? userDeviceKeysLoading;
  Future? roomsLoading;
  Future? _accountDataLoading;
  Future? _discoveryDataLoading;
  Future? firstSyncReceived;

  Future? get accountDataLoading => _accountDataLoading;

  Future? get wellKnownLoading => _discoveryDataLoading;

  /// A map of known device keys per user.
  Map<String, DeviceKeysList> get userDeviceKeys => _userDeviceKeys;
  Map<String, DeviceKeysList> _userDeviceKeys = {};

  /// A list of all not verified and not blocked device keys. Clients should
  /// display a warning if this list is not empty and suggest the user to
  /// verify or block those devices.
  List<DeviceKeys> get unverifiedDevices {
    final userId = userID;
    if (userId == null) return [];
    return userDeviceKeys[userId]
            ?.deviceKeys
            .values
            .where((deviceKey) => !deviceKey.verified && !deviceKey.blocked)
            .toList() ??
        [];
  }

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
      if (room.encrypted && room.membership == Membership.join) {
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

  Future<void> updateUserDeviceKeys({Set<String>? additionalUsers}) async {
    try {
      final database = this.database;
      if (!isLogged() || database == null) return;
      final dbActions = <Future<dynamic> Function()>[];
      final trackedUserIds = await _getUserIdsInEncryptedRooms();
      if (!isLogged()) return;
      trackedUserIds.add(userID!);
      if (additionalUsers != null) trackedUserIds.addAll(additionalUsers);

      // Remove all userIds we no longer need to track the devices of.
      _userDeviceKeys
          .removeWhere((String userId, v) => !trackedUserIds.contains(userId));

      // Check if there are outdated device key lists. Add it to the set.
      final outdatedLists = <String, List<String>>{};
      for (final userId in (additionalUsers ?? <String>[])) {
        outdatedLists[userId] = [];
      }
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
                rawDeviceKeyEntry.value,
                this,
                oldKeys[deviceId]?.lastActive,
              );
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
                      'Already seen Device ID has been added again. This might be an attack!',
                    );
                    continue;
                  }
                  final oldDeviceId = await database.publicKeySeen(ed25519Key);
                  if (oldDeviceId != null && oldDeviceId != deviceId) {
                    Logs().w(
                      'Already seen ED25519 has been added again. This might be an attack!',
                    );
                    continue;
                  }
                  final oldDeviceId2 =
                      await database.publicKeySeen(curve25519Key);
                  if (oldDeviceId2 != null && oldDeviceId2 != deviceId) {
                    Logs().w(
                      'Already seen Curve25519 has been added again. This might be an attack!',
                    );
                    continue;
                  }
                  await database.addSeenDeviceId(
                    userId,
                    deviceId,
                    curve25519Key + ed25519Key,
                  );
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
                  dbActions.add(
                    () => database.storeUserDeviceKey(
                      userId,
                      deviceId,
                      json.encode(entry.toJson()),
                      entry.directVerified,
                      entry.blocked,
                      entry.lastActive.millisecondsSinceEpoch,
                    ),
                  );
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
                dbActions.add(
                  () =>
                      database.removeUserCrossSigningKey(userId, oldEntry.key),
                );
              }
            }
            final entry = CrossSigningKey.fromMatrixCrossSigningKey(
              crossSigningKeyListEntry.value,
              this,
            );
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
              dbActions.add(
                () => database.storeUserCrossSigningKey(
                  userId,
                  publicKey,
                  json.encode(entry.toJson()),
                  entry.directVerified,
                  entry.blocked,
                ),
              );
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
      final data = entry.content.map(
        (k, v) => MapEntry<String, Map<String, Map<String, dynamic>>>(
          k,
          (v as Map).map(
            (k, v) => MapEntry<String, Map<String, dynamic>>(
              k,
              Map<String, dynamic>.from(v),
            ),
          ),
        ),
      );

      try {
        await super.sendToDevice(entry.type, entry.txnId, data);
      } on MatrixException catch (e) {
        Logs().w(
          '[To-Device] failed to to_device message from the queue to the server. Ignoring error: $e',
        );
        Logs().w('Payload: $data');
      }
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
        s,
      );
      final database = this.database;
      if (database != null) {
        _toDeviceQueueNeedsProcessing = true;
        await database.insertIntoToDeviceQueue(
          eventType,
          txnId,
          json.encode(messages),
        );
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
      eventType,
      messageId ?? generateUniqueTransactionId(),
      data,
    );
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
      deviceKeys.removeWhere(
        (DeviceKeys deviceKeys) =>
            deviceKeys.blocked ||
            (deviceKeys.userId == userID && deviceKeys.deviceId == deviceID) ||
            (onlyVerified && !deviceKeys.verified),
      );
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
        deviceKeys,
        eventType,
        message,
      );
      eventType = EventTypes.Encrypted;
      await sendToDevice(
        eventType,
        messageId ?? generateUniqueTransactionId(),
        data,
      );
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
    deviceKeys.removeWhere(
      (DeviceKeys k) =>
          k.blocked || (k.userId == userID && k.deviceId == deviceID),
    );
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
        i + chunkSize > deviceKeys.length ? deviceKeys.length : i + chunkSize,
      );
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
                : i + chunkSize,
          );
          // and send
          await sendToDeviceEncrypted(chunk, eventType, message);
        }
      }();
    }
  }

  /// Whether all push notifications are muted using the [.m.rule.master]
  /// rule of the push rules: https://matrix.org/docs/spec/client_server/r0.6.0#m-rule-master
  bool get allPushNotificationsMuted {
    final Map<String, Object?>? globalPushRules =
        _accountData[EventTypes.PushRules]
            ?.content
            .tryGetMap<String, Object?>('global');
    if (globalPushRules == null) return false;

    final globalPushRulesOverride = globalPushRules.tryGetList('override');
    if (globalPushRulesOverride != null) {
      for (final pushRule in globalPushRulesOverride) {
        if (pushRule['rule_id'] == '.m.rule.master') {
          return pushRule['enabled'];
        }
      }
    }
    return false;
  }

  Future<void> setMuteAllPushNotifications(bool muted) async {
    await setPushRuleEnabled(
      PushRuleKind.override,
      '.m.rule.master',
      muted,
    );
    return;
  }

  /// preference is always given to via over serverName, irrespective of what field
  /// you are trying to use
  @override
  Future<String> joinRoom(
    String roomIdOrAlias, {
    List<String>? serverName,
    List<String>? via,
    String? reason,
    ThirdPartySigned? thirdPartySigned,
  }) =>
      super.joinRoom(
        roomIdOrAlias,
        serverName: via ?? serverName,
        via: via ?? serverName,
        reason: reason,
        thirdPartySigned: thirdPartySigned,
      );

  /// Changes the password. You should either set oldPasswort or another authentication flow.
  @override
  Future<void> changePassword(
    String newPassword, {
    String? oldPassword,
    AuthenticationData? auth,
    bool? logoutDevices,
  }) async {
    final userID = this.userID;
    try {
      if (oldPassword != null && userID != null) {
        auth = AuthenticationPassword(
          identifier: AuthenticationUserIdentifier(user: userID),
          password: oldPassword,
        );
      }
      await super.changePassword(
        newPassword,
        auth: auth,
        logoutDevices: logoutDevices,
      );
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
      if (oldPassword == null || userID == null) {
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

  /// Clear all local cached messages, room information and outbound group
  /// sessions and perform a new clean sync.
  Future<void> clearCache() async {
    await abortSync();
    _prevBatch = null;
    rooms.clear();
    await database?.clearCache();
    encryption?.keyManager.clearOutboundGroupSessions();
    _eventsPendingDecryption.clear();
    onCacheCleared.add(true);
    // Restart the syncloop
    backgroundSync = true;
  }

  /// A list of mxids of users who are ignored.
  List<String> get ignoredUsers => List<String>.from(
        _accountData['m.ignored_user_list']
                ?.content
                .tryGetMap<String, Object?>('ignored_users')
                ?.keys ??
            <String>[],
      );

  /// Ignore another user. This will clear the local cached messages to
  /// hide all previous messages from this user.
  Future<void> ignoreUser(String userId) async {
    if (!userId.isValidMatrixId) {
      throw Exception('$userId is not a valid mxid!');
    }
    await setAccountData(userID!, 'm.ignored_user_list', {
      'ignored_users': Map.fromEntries(
        (ignoredUsers..add(userId)).map((key) => MapEntry(key, {})),
      ),
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
        (ignoredUsers..remove(userId)).map((key) => MapEntry(key, {})),
      ),
    });
    await clearCache();
    return;
  }

  /// The newest presence of this user if there is any. Fetches it from the
  /// database first and then from the server if necessary or returns offline.
  Future<CachedPresence> fetchCurrentPresence(
    String userId, {
    bool fetchOnlyFromCached = false,
  }) async {
    // ignore: deprecated_member_use_from_same_package
    final cachedPresence = presences[userId];
    if (cachedPresence != null) {
      return cachedPresence;
    }

    final dbPresence = await database?.getPresence(userId);
    // ignore: deprecated_member_use_from_same_package
    if (dbPresence != null) return presences[userId] = dbPresence;

    if (fetchOnlyFromCached) return CachedPresence.neverSeen(userId);

    try {
      final result = await getPresence(userId);
      final presence = CachedPresence.fromPresenceResponse(result, userId);
      await database?.storePresence(userId, presence);
      // ignore: deprecated_member_use_from_same_package
      return presences[userId] = presence;
    } catch (e) {
      final presence = CachedPresence.neverSeen(userId);
      await database?.storePresence(userId, presence);
      // ignore: deprecated_member_use_from_same_package
      return presences[userId] = presence;
    }
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
    await encryption?.dispose();
    _encryption = null;
    try {
      if (closeDatabase) {
        final database = _database;
        _database = null;
        await database
            ?.close()
            .catchError((e, s) => Logs().w('Failed to close database: ', e, s));
      }
    } catch (error, stacktrace) {
      Logs().w('Failed to close database: ', error, stacktrace);
    }
    return;
  }

  Future<void> _migrateFromLegacyDatabase({
    void Function(InitState)? onInitStateChanged,
    void Function()? onMigration,
  }) async {
    Logs().i('Check legacy database for migration data...');
    final legacyDatabase = await legacyDatabaseBuilder?.call(this);
    final migrateClient = await legacyDatabase?.getClient(clientName);
    final database = this.database;

    if (migrateClient == null || legacyDatabase == null || database == null) {
      await legacyDatabase?.close();
      _initLock = false;
      return;
    }
    Logs().i('Found data in the legacy database!');
    onInitStateChanged?.call(InitState.migratingDatabase);
    onMigration?.call();
    _id = migrateClient['client_id'];
    final tokenExpiresAtMs =
        int.tryParse(migrateClient.tryGet<String>('token_expires_at') ?? '');
    await database.insertClient(
      clientName,
      migrateClient['homeserver_url'],
      migrateClient['token'],
      tokenExpiresAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(tokenExpiresAtMs),
      migrateClient['refresh_token'],
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
    Logs().d('Migrate OLM sessions...');
    try {
      final olmSessions = await legacyDatabase.getAllOlmSessions();
      for (final identityKey in olmSessions.keys) {
        final sessions = olmSessions[identityKey]!;
        for (final sessionId in sessions.keys) {
          final session = sessions[sessionId]!;
          await database.storeOlmSession(
            identityKey,
            session['session_id'] as String,
            session['pickle'] as String,
            session['last_received'] as int,
          );
        }
      }
    } catch (e, s) {
      Logs().e('Unable to migrate OLM sessions!', e, s);
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
            'Migrate cross signing key with usage ${crossSigningKey.usage} and verified ${crossSigningKey.directVerified}...',
          );
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
        await database.storeUserDeviceKeysInfo(userId, deviceKeysList.outdated);
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
    await legacyDatabase.delete();

    _initLock = false;
    return init(
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: false,
      onInitStateChanged: onInitStateChanged,
    );
  }
}

class SdkError {
  dynamic exception;
  StackTrace? stackTrace;

  SdkError({this.exception, this.stackTrace});
}

class SyncConnectionException implements Exception {
  final Object originalException;

  SyncConnectionException(this.originalException);
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

class BadServerLoginTypesException implements Exception {
  final Set<String> serverLoginTypes, supportedLoginTypes;

  BadServerLoginTypesException(this.serverLoginTypes, this.supportedLoginTypes);

  @override
  String toString() =>
      'Server supports the Login Types: ${serverLoginTypes.toString()} but this application is only compatible with ${supportedLoginTypes.toString()}.';
}

class FileTooBigMatrixException extends MatrixException {
  int actualFileSize;
  int maxFileSize;

  static String _formatFileSize(int size) {
    if (size < 1000) return '$size B';
    final i = (log(size) / log(1000)).floor();
    final num = (size / pow(1000, i));
    final round = num.round();
    final numString = round < 10
        ? num.toStringAsFixed(2)
        : round < 100
            ? num.toStringAsFixed(1)
            : round.toString();
    return '$numString ${'kMGTPEZY'[i - 1]}B';
  }

  FileTooBigMatrixException(this.actualFileSize, this.maxFileSize)
      : super.fromJson({
          'errcode': MatrixError.M_TOO_LARGE,
          'error':
              'File size ${_formatFileSize(actualFileSize)} exceeds allowed maximum of ${_formatFileSize(maxFileSize)}',
        });

  @override
  String toString() =>
      'File size ${_formatFileSize(actualFileSize)} exceeds allowed maximum of ${_formatFileSize(maxFileSize)}';
}

class ArchivedRoom {
  final Room room;
  final Timeline timeline;

  ArchivedRoom({required this.room, required this.timeline});
}

/// An event that is waiting for a key to arrive to decrypt. Times out after some time.
class _EventPendingDecryption {
  DateTime addedAt = DateTime.now();

  Event event;

  bool get timedOut =>
      addedAt.add(Duration(minutes: 5)).isBefore(DateTime.now());

  _EventPendingDecryption(this.event);
}

enum InitState {
  /// Initialization has been started. Client fetches information from the database.
  initializing,

  /// The database has been updated. A migration is in progress.
  migratingDatabase,

  /// The encryption module will be set up now. For the first login this also
  /// includes uploading keys to the server.
  settingUpEncryption,

  /// The client is loading rooms, device keys and account data from the
  /// database.
  loadingData,

  /// The client waits now for the first sync before procceeding. Get more
  /// information from `Client.onSyncUpdate`.
  waitingForFirstSync,

  /// Initialization is complete without errors. The client is now either
  /// logged in or no active session was found.
  finished,

  /// Initialization has been completed with an error.
  error,
}

/// Sets the security level with which devices keys should be shared with
enum ShareKeysWith {
  /// Keys are shared with all devices if they are not explicitely blocked
  all,

  /// Once a user has enabled cross signing, keys are no longer shared with
  /// devices which are not cross verified by the cross signing keys of this
  /// user. This does not require that the user needs to be verified.
  crossVerifiedIfEnabled,

  /// Keys are only shared with cross verified devices. If a user has not
  /// enabled cross signing, then all devices must be verified manually first.
  /// This does not require that the user needs to be verified.
  crossVerified,

  /// Keys are only shared with direct verified devices. So either the device
  /// or the user must be manually verified first, before keys are shared. By
  /// using cross signing, it is enough to verify the user and then the user
  /// can verify their devices.
  directlyVerifiedOnly,
}
