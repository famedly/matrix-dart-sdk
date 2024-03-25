import 'package:enhanced_enum/enhanced_enum.dart';

import 'package:matrix/matrix_api_lite/model/children_state.dart';
import 'package:matrix/matrix_api_lite/model/matrix_event.dart';
import 'package:matrix/matrix_api_lite/model/matrix_keys.dart';

part 'model.g.dart';

class _NameSource {
  final String source;
  const _NameSource(this.source);
}

///
@_NameSource('spec')
class HomeserverInformation {
  HomeserverInformation({
    required this.baseUrl,
  });

  HomeserverInformation.fromJson(Map<String, Object?> json)
      : baseUrl = Uri.parse(json['base_url'] as String);
  Map<String, Object?> toJson() => {
        'base_url': baseUrl.toString(),
      };

  /// The base URL for the homeserver for client-server connections.
  Uri baseUrl;
}

///
@_NameSource('spec')
class IdentityServerInformation {
  IdentityServerInformation({
    required this.baseUrl,
  });

  IdentityServerInformation.fromJson(Map<String, Object?> json)
      : baseUrl = Uri.parse(json['base_url'] as String);
  Map<String, Object?> toJson() => {
        'base_url': baseUrl.toString(),
      };

  /// The base URL for the identity server for client-server connections.
  Uri baseUrl;
}

/// Used by clients to determine the homeserver, identity server, and other
/// optional components they should be interacting with.
@_NameSource('spec')
class DiscoveryInformation {
  DiscoveryInformation({
    required this.mHomeserver,
    this.mIdentityServer,
    this.additionalProperties = const {},
  });

  DiscoveryInformation.fromJson(Map<String, Object?> json)
      : mHomeserver = HomeserverInformation.fromJson(
            json['m.homeserver'] as Map<String, Object?>),
        mIdentityServer = ((v) => v != null
            ? IdentityServerInformation.fromJson(v as Map<String, Object?>)
            : null)(json['m.identity_server']),
        additionalProperties = Map.fromEntries(json.entries
            .where(
                (e) => !['m.homeserver', 'm.identity_server'].contains(e.key))
            .map((e) => MapEntry(e.key, e.value as Map<String, Object?>)));
  Map<String, Object?> toJson() {
    final mIdentityServer = this.mIdentityServer;
    return {
      ...additionalProperties,
      'm.homeserver': mHomeserver.toJson(),
      if (mIdentityServer != null)
        'm.identity_server': mIdentityServer.toJson(),
    };
  }

  /// Used by clients to discover homeserver information.
  HomeserverInformation mHomeserver;

  /// Used by clients to discover identity server information.
  IdentityServerInformation? mIdentityServer;

  Map<String, Map<String, Object?>> additionalProperties;
}

///
@_NameSource('spec')
class PublicRoomsChunk {
  PublicRoomsChunk({
    this.avatarUrl,
    this.canonicalAlias,
    required this.guestCanJoin,
    this.joinRule,
    this.name,
    required this.numJoinedMembers,
    required this.roomId,
    this.roomType,
    this.topic,
    required this.worldReadable,
  });

  PublicRoomsChunk.fromJson(Map<String, Object?> json)
      : avatarUrl = ((v) =>
            v != null ? Uri.parse(v as String) : null)(json['avatar_url']),
        canonicalAlias =
            ((v) => v != null ? v as String : null)(json['canonical_alias']),
        guestCanJoin = json['guest_can_join'] as bool,
        joinRule = ((v) => v != null ? v as String : null)(json['join_rule']),
        name = ((v) => v != null ? v as String : null)(json['name']),
        numJoinedMembers = json['num_joined_members'] as int,
        roomId = json['room_id'] as String,
        roomType = ((v) => v != null ? v as String : null)(json['room_type']),
        topic = ((v) => v != null ? v as String : null)(json['topic']),
        worldReadable = json['world_readable'] as bool;
  Map<String, Object?> toJson() {
    final avatarUrl = this.avatarUrl;
    final canonicalAlias = this.canonicalAlias;
    final joinRule = this.joinRule;
    final name = this.name;
    final roomType = this.roomType;
    final topic = this.topic;
    return {
      if (avatarUrl != null) 'avatar_url': avatarUrl.toString(),
      if (canonicalAlias != null) 'canonical_alias': canonicalAlias,
      'guest_can_join': guestCanJoin,
      if (joinRule != null) 'join_rule': joinRule,
      if (name != null) 'name': name,
      'num_joined_members': numJoinedMembers,
      'room_id': roomId,
      if (roomType != null) 'room_type': roomType,
      if (topic != null) 'topic': topic,
      'world_readable': worldReadable,
    };
  }

  /// The URL for the room's avatar, if one is set.
  Uri? avatarUrl;

  /// The canonical alias of the room, if any.
  String? canonicalAlias;

  /// Whether guest users may join the room and participate in it.
  /// If they can, they will be subject to ordinary power level
  /// rules like any other user.
  bool guestCanJoin;

  /// The room's join rule. When not present, the room is assumed to
  /// be `public`.
  String? joinRule;

  /// The name of the room, if any.
  String? name;

  /// The number of members joined to the room.
  int numJoinedMembers;

  /// The ID of the room.
  String roomId;

  /// The `type` of room (from [`m.room.create`](https://spec.matrix.org/unstable/client-server-api/#mroomcreate)), if any.
  String? roomType;

  /// The topic of the room, if any.
  String? topic;

  /// Whether the room may be viewed by guest users without joining.
  bool worldReadable;
}

///
@_NameSource('spec')
class ChildRoomsChunk {
  ChildRoomsChunk({
    required this.childrenState,
    this.roomType,
  });

  ChildRoomsChunk.fromJson(Map<String, Object?> json)
      : childrenState = (json['children_state'] as List)
            .map((v) => ChildrenState.fromJson(v as Map<String, Object?>))
            .toList(),
        roomType = ((v) => v != null ? v as String : null)(json['room_type']);
  Map<String, Object?> toJson() {
    final roomType = this.roomType;
    return {
      'children_state': childrenState.map((v) => v.toJson()).toList(),
      if (roomType != null) 'room_type': roomType,
    };
  }

  /// The [`m.space.child`](#mspacechild) events of the space-room, represented
  /// as [Stripped State Events](#stripped-state) with an added `origin_server_ts` key.
  ///
  /// If the room is not a space-room, this should be empty.
  List<ChildrenState> childrenState;

  /// The `type` of room (from [`m.room.create`](https://spec.matrix.org/unstable/client-server-api/#mroomcreate)), if any.
  String? roomType;
}

///
@_NameSource('rule override generated')
class SpaceRoomsChunk implements PublicRoomsChunk, ChildRoomsChunk {
  SpaceRoomsChunk({
    this.avatarUrl,
    this.canonicalAlias,
    required this.guestCanJoin,
    this.joinRule,
    this.name,
    required this.numJoinedMembers,
    required this.roomId,
    this.roomType,
    this.topic,
    required this.worldReadable,
    required this.childrenState,
  });

  SpaceRoomsChunk.fromJson(Map<String, Object?> json)
      : avatarUrl = ((v) =>
            v != null ? Uri.parse(v as String) : null)(json['avatar_url']),
        canonicalAlias =
            ((v) => v != null ? v as String : null)(json['canonical_alias']),
        guestCanJoin = json['guest_can_join'] as bool,
        joinRule = ((v) => v != null ? v as String : null)(json['join_rule']),
        name = ((v) => v != null ? v as String : null)(json['name']),
        numJoinedMembers = json['num_joined_members'] as int,
        roomId = json['room_id'] as String,
        roomType = ((v) => v != null ? v as String : null)(json['room_type']),
        topic = ((v) => v != null ? v as String : null)(json['topic']),
        worldReadable = json['world_readable'] as bool,
        childrenState = (json['children_state'] as List)
            .map((v) => ChildrenState.fromJson(v as Map<String, Object?>))
            .toList();
  @override
  Map<String, Object?> toJson() {
    final avatarUrl = this.avatarUrl;
    final canonicalAlias = this.canonicalAlias;
    final joinRule = this.joinRule;
    final name = this.name;
    final roomType = this.roomType;
    final topic = this.topic;
    return {
      if (avatarUrl != null) 'avatar_url': avatarUrl.toString(),
      if (canonicalAlias != null) 'canonical_alias': canonicalAlias,
      'guest_can_join': guestCanJoin,
      if (joinRule != null) 'join_rule': joinRule,
      if (name != null) 'name': name,
      'num_joined_members': numJoinedMembers,
      'room_id': roomId,
      if (roomType != null) 'room_type': roomType,
      if (topic != null) 'topic': topic,
      'world_readable': worldReadable,
      'children_state': childrenState.map((v) => v.toJson()).toList(),
    };
  }

  /// The URL for the room's avatar, if one is set.
  @override
  Uri? avatarUrl;

  /// The canonical alias of the room, if any.
  @override
  String? canonicalAlias;

  /// Whether guest users may join the room and participate in it.
  /// If they can, they will be subject to ordinary power level
  /// rules like any other user.
  @override
  bool guestCanJoin;

  /// The room's join rule. When not present, the room is assumed to
  /// be `public`.
  @override
  String? joinRule;

  /// The name of the room, if any.
  @override
  String? name;

  /// The number of members joined to the room.
  @override
  int numJoinedMembers;

  /// The ID of the room.
  @override
  String roomId;

  /// The `type` of room (from [`m.room.create`](https://spec.matrix.org/unstable/client-server-api/#mroomcreate)), if any.
  @override
  String? roomType;

  /// The topic of the room, if any.
  @override
  String? topic;

  /// Whether the room may be viewed by guest users without joining.
  @override
  bool worldReadable;

  /// The [`m.space.child`](#mspacechild) events of the space-room, represented
  /// as [Stripped State Events](#stripped-state) with an added `origin_server_ts` key.
  ///
  /// If the room is not a space-room, this should be empty.
  @override
  List<ChildrenState> childrenState;
}

///
@_NameSource('generated')
class GetSpaceHierarchyResponse {
  GetSpaceHierarchyResponse({
    this.nextBatch,
    required this.rooms,
  });

  GetSpaceHierarchyResponse.fromJson(Map<String, Object?> json)
      : nextBatch = ((v) => v != null ? v as String : null)(json['next_batch']),
        rooms = (json['rooms'] as List)
            .map((v) => SpaceRoomsChunk.fromJson(v as Map<String, Object?>))
            .toList();
  Map<String, Object?> toJson() {
    final nextBatch = this.nextBatch;
    return {
      if (nextBatch != null) 'next_batch': nextBatch,
      'rooms': rooms.map((v) => v.toJson()).toList(),
    };
  }

  /// A token to supply to `from` to keep paginating the responses. Not present when there are
  /// no further results.
  String? nextBatch;

  /// The rooms for the current page, with the current filters.
  List<SpaceRoomsChunk> rooms;
}

///
@_NameSource('rule override generated')
@EnhancedEnum()
enum Direction {
  @EnhancedEnumValue(name: 'b')
  b,
  @EnhancedEnumValue(name: 'f')
  f
}

///
@_NameSource('generated')
class GetRelatingEventsResponse {
  GetRelatingEventsResponse({
    required this.chunk,
    this.nextBatch,
    this.prevBatch,
  });

  GetRelatingEventsResponse.fromJson(Map<String, Object?> json)
      : chunk = (json['chunk'] as List)
            .map((v) => MatrixEvent.fromJson(v as Map<String, Object?>))
            .toList(),
        nextBatch = ((v) => v != null ? v as String : null)(json['next_batch']),
        prevBatch = ((v) => v != null ? v as String : null)(json['prev_batch']);
  Map<String, Object?> toJson() {
    final nextBatch = this.nextBatch;
    final prevBatch = this.prevBatch;
    return {
      'chunk': chunk.map((v) => v.toJson()).toList(),
      if (nextBatch != null) 'next_batch': nextBatch,
      if (prevBatch != null) 'prev_batch': prevBatch,
    };
  }

  /// The child events of the requested event, ordered topologically most-recent first.
  List<MatrixEvent> chunk;

  /// An opaque string representing a pagination token. The absence of this token
  /// means there are no more results to fetch and the client should stop paginating.
  String? nextBatch;

  /// An opaque string representing a pagination token. The absence of this token
  /// means this is the start of the result set, i.e. this is the first batch/page.
  String? prevBatch;
}

///
@_NameSource('generated')
class GetRelatingEventsWithRelTypeResponse {
  GetRelatingEventsWithRelTypeResponse({
    required this.chunk,
    this.nextBatch,
    this.prevBatch,
  });

  GetRelatingEventsWithRelTypeResponse.fromJson(Map<String, Object?> json)
      : chunk = (json['chunk'] as List)
            .map((v) => MatrixEvent.fromJson(v as Map<String, Object?>))
            .toList(),
        nextBatch = ((v) => v != null ? v as String : null)(json['next_batch']),
        prevBatch = ((v) => v != null ? v as String : null)(json['prev_batch']);
  Map<String, Object?> toJson() {
    final nextBatch = this.nextBatch;
    final prevBatch = this.prevBatch;
    return {
      'chunk': chunk.map((v) => v.toJson()).toList(),
      if (nextBatch != null) 'next_batch': nextBatch,
      if (prevBatch != null) 'prev_batch': prevBatch,
    };
  }

  /// The child events of the requested event, ordered topologically
  /// most-recent first. The events returned will match the `relType`
  /// supplied in the URL.
  List<MatrixEvent> chunk;

  /// An opaque string representing a pagination token. The absence of this token
  /// means there are no more results to fetch and the client should stop paginating.
  String? nextBatch;

  /// An opaque string representing a pagination token. The absence of this token
  /// means this is the start of the result set, i.e. this is the first batch/page.
  String? prevBatch;
}

///
@_NameSource('generated')
class GetRelatingEventsWithRelTypeAndEventTypeResponse {
  GetRelatingEventsWithRelTypeAndEventTypeResponse({
    required this.chunk,
    this.nextBatch,
    this.prevBatch,
  });

  GetRelatingEventsWithRelTypeAndEventTypeResponse.fromJson(
      Map<String, Object?> json)
      : chunk = (json['chunk'] as List)
            .map((v) => MatrixEvent.fromJson(v as Map<String, Object?>))
            .toList(),
        nextBatch = ((v) => v != null ? v as String : null)(json['next_batch']),
        prevBatch = ((v) => v != null ? v as String : null)(json['prev_batch']);
  Map<String, Object?> toJson() {
    final nextBatch = this.nextBatch;
    final prevBatch = this.prevBatch;
    return {
      'chunk': chunk.map((v) => v.toJson()).toList(),
      if (nextBatch != null) 'next_batch': nextBatch,
      if (prevBatch != null) 'prev_batch': prevBatch,
    };
  }

  /// The child events of the requested event, ordered topologically most-recent
  /// first. The events returned will match the `relType` and `eventType` supplied
  /// in the URL.
  List<MatrixEvent> chunk;

  /// An opaque string representing a pagination token. The absence of this token
  /// means there are no more results to fetch and the client should stop paginating.
  String? nextBatch;

  /// An opaque string representing a pagination token. The absence of this token
  /// means this is the start of the result set, i.e. this is the first batch/page.
  String? prevBatch;
}

///
@_NameSource('generated')
@EnhancedEnum()
enum Include {
  @EnhancedEnumValue(name: 'all')
  all,
  @EnhancedEnumValue(name: 'participated')
  participated
}

///
@_NameSource('generated')
class GetThreadRootsResponse {
  GetThreadRootsResponse({
    required this.chunk,
    this.nextBatch,
  });

  GetThreadRootsResponse.fromJson(Map<String, Object?> json)
      : chunk = (json['chunk'] as List)
            .map((v) => MatrixEvent.fromJson(v as Map<String, Object?>))
            .toList(),
        nextBatch = ((v) => v != null ? v as String : null)(json['next_batch']);
  Map<String, Object?> toJson() {
    final nextBatch = this.nextBatch;
    return {
      'chunk': chunk.map((v) => v.toJson()).toList(),
      if (nextBatch != null) 'next_batch': nextBatch,
    };
  }

  /// The thread roots, ordered by the `latest_event` in each event's aggregation bundle. All events
  /// returned include bundled [aggregations](https://spec.matrix.org/unstable/client-server-api/#aggregations).
  ///
  /// If the thread root event was sent by an [ignored user](https://spec.matrix.org/unstable/client-server-api/#ignoring-users), the
  /// event is returned redacted to the caller. This is to simulate the same behaviour of a client doing
  /// aggregation locally on the thread.
  List<MatrixEvent> chunk;

  /// A token to supply to `from` to keep paginating the responses. Not present when there are
  /// no further results.
  String? nextBatch;
}

///
@_NameSource('generated')
class GetEventByTimestampResponse {
  GetEventByTimestampResponse({
    required this.eventId,
    required this.originServerTs,
  });

  GetEventByTimestampResponse.fromJson(Map<String, Object?> json)
      : eventId = json['event_id'] as String,
        originServerTs = json['origin_server_ts'] as int;
  Map<String, Object?> toJson() => {
        'event_id': eventId,
        'origin_server_ts': originServerTs,
      };

  /// The ID of the event found
  String eventId;

  /// The event's timestamp, in milliseconds since the Unix epoch.
  /// This makes it easy to do a quick comparison to see if the
  /// `event_id` fetched is too far out of range to be useful for your
  /// use case.
  int originServerTs;
}

///
@_NameSource('rule override generated')
@EnhancedEnum()
enum ThirdPartyIdentifierMedium {
  @EnhancedEnumValue(name: 'email')
  email,
  @EnhancedEnumValue(name: 'msisdn')
  msisdn
}

///
@_NameSource('spec')
class ThirdPartyIdentifier {
  ThirdPartyIdentifier({
    required this.addedAt,
    required this.address,
    required this.medium,
    required this.validatedAt,
  });

  ThirdPartyIdentifier.fromJson(Map<String, Object?> json)
      : addedAt = json['added_at'] as int,
        address = json['address'] as String,
        medium = ThirdPartyIdentifierMedium.values
            .fromString(json['medium'] as String)!,
        validatedAt = json['validated_at'] as int;
  Map<String, Object?> toJson() => {
        'added_at': addedAt,
        'address': address,
        'medium': medium.name,
        'validated_at': validatedAt,
      };

  /// The timestamp, in milliseconds, when the homeserver associated the third party identifier with the user.
  int addedAt;

  /// The third party identifier address.
  String address;

  /// The medium of the third party identifier.
  ThirdPartyIdentifierMedium medium;

  /// The timestamp, in milliseconds, when the identifier was
  /// validated by the identity server.
  int validatedAt;
}

///
@_NameSource('spec')
class ThreePidCredentials {
  ThreePidCredentials({
    required this.clientSecret,
    required this.idAccessToken,
    required this.idServer,
    required this.sid,
  });

  ThreePidCredentials.fromJson(Map<String, Object?> json)
      : clientSecret = json['client_secret'] as String,
        idAccessToken = json['id_access_token'] as String,
        idServer = json['id_server'] as String,
        sid = json['sid'] as String;
  Map<String, Object?> toJson() => {
        'client_secret': clientSecret,
        'id_access_token': idAccessToken,
        'id_server': idServer,
        'sid': sid,
      };

  /// The client secret used in the session with the identity server.
  String clientSecret;

  /// An access token previously registered with the identity server. Servers
  /// can treat this as optional to distinguish between r0.5-compatible clients
  /// and this specification version.
  String idAccessToken;

  /// The identity server to use.
  String idServer;

  /// The session identifier given by the identity server.
  String sid;
}

///
@_NameSource('generated')
@EnhancedEnum()
enum IdServerUnbindResult {
  @EnhancedEnumValue(name: 'no-support')
  noSupport,
  @EnhancedEnumValue(name: 'success')
  success
}

///
@_NameSource('spec')
class RequestTokenResponse {
  RequestTokenResponse({
    required this.sid,
    this.submitUrl,
  });

  RequestTokenResponse.fromJson(Map<String, Object?> json)
      : sid = json['sid'] as String,
        submitUrl = ((v) =>
            v != null ? Uri.parse(v as String) : null)(json['submit_url']);
  Map<String, Object?> toJson() {
    final submitUrl = this.submitUrl;
    return {
      'sid': sid,
      if (submitUrl != null) 'submit_url': submitUrl.toString(),
    };
  }

  /// The session ID. Session IDs are opaque strings that must consist entirely
  /// of the characters `[0-9a-zA-Z.=_-]`. Their length must not exceed 255
  /// characters and they must not be empty.
  String sid;

  /// An optional field containing a URL where the client must submit the
  /// validation token to, with identical parameters to the Identity Service
  /// API's `POST /validate/email/submitToken` endpoint (without the requirement
  /// for an access token). The homeserver must send this token to the user (if
  /// applicable), who should then be prompted to provide it to the client.
  ///
  /// If this field is not present, the client can assume that verification
  /// will happen without the client's involvement provided the homeserver
  /// advertises this specification version in the `/versions` response
  /// (ie: r0.5.0).
  Uri? submitUrl;
}

///
@_NameSource('rule override generated')
class TokenOwnerInfo {
  TokenOwnerInfo({
    this.deviceId,
    this.isGuest,
    required this.userId,
  });

  TokenOwnerInfo.fromJson(Map<String, Object?> json)
      : deviceId = ((v) => v != null ? v as String : null)(json['device_id']),
        isGuest = ((v) => v != null ? v as bool : null)(json['is_guest']),
        userId = json['user_id'] as String;
  Map<String, Object?> toJson() {
    final deviceId = this.deviceId;
    final isGuest = this.isGuest;
    return {
      if (deviceId != null) 'device_id': deviceId,
      if (isGuest != null) 'is_guest': isGuest,
      'user_id': userId,
    };
  }

  /// Device ID associated with the access token. If no device
  /// is associated with the access token (such as in the case
  /// of application services) then this field can be omitted.
  /// Otherwise this is required.
  String? deviceId;

  /// When `true`, the user is a [Guest User](#guest-access). When
  /// not present or `false`, the user is presumed to be a non-guest
  /// user.
  bool? isGuest;

  /// The user ID that owns the access token.
  String userId;
}

///
@_NameSource('spec')
class ConnectionInfo {
  ConnectionInfo({
    this.ip,
    this.lastSeen,
    this.userAgent,
  });

  ConnectionInfo.fromJson(Map<String, Object?> json)
      : ip = ((v) => v != null ? v as String : null)(json['ip']),
        lastSeen = ((v) => v != null ? v as int : null)(json['last_seen']),
        userAgent = ((v) => v != null ? v as String : null)(json['user_agent']);
  Map<String, Object?> toJson() {
    final ip = this.ip;
    final lastSeen = this.lastSeen;
    final userAgent = this.userAgent;
    return {
      if (ip != null) 'ip': ip,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (userAgent != null) 'user_agent': userAgent,
    };
  }

  /// Most recently seen IP address of the session.
  String? ip;

  /// Unix timestamp that the session was last active.
  int? lastSeen;

  /// User agent string last seen in the session.
  String? userAgent;
}

///
@_NameSource('spec')
class SessionInfo {
  SessionInfo({
    this.connections,
  });

  SessionInfo.fromJson(Map<String, Object?> json)
      : connections = ((v) => v != null
            ? (v as List)
                .map((v) => ConnectionInfo.fromJson(v as Map<String, Object?>))
                .toList()
            : null)(json['connections']);
  Map<String, Object?> toJson() {
    final connections = this.connections;
    return {
      if (connections != null)
        'connections': connections.map((v) => v.toJson()).toList(),
    };
  }

  /// Information particular connections in the session.
  List<ConnectionInfo>? connections;
}

///
@_NameSource('spec')
class DeviceInfo {
  DeviceInfo({
    this.sessions,
  });

  DeviceInfo.fromJson(Map<String, Object?> json)
      : sessions = ((v) => v != null
            ? (v as List)
                .map((v) => SessionInfo.fromJson(v as Map<String, Object?>))
                .toList()
            : null)(json['sessions']);
  Map<String, Object?> toJson() {
    final sessions = this.sessions;
    return {
      if (sessions != null)
        'sessions': sessions.map((v) => v.toJson()).toList(),
    };
  }

  /// A user's sessions (i.e. what they did with an access token from one login).
  List<SessionInfo>? sessions;
}

///
@_NameSource('rule override generated')
class WhoIsInfo {
  WhoIsInfo({
    this.devices,
    this.userId,
  });

  WhoIsInfo.fromJson(Map<String, Object?> json)
      : devices = ((v) => v != null
            ? (v as Map<String, Object?>).map((k, v) =>
                MapEntry(k, DeviceInfo.fromJson(v as Map<String, Object?>)))
            : null)(json['devices']),
        userId = ((v) => v != null ? v as String : null)(json['user_id']);
  Map<String, Object?> toJson() {
    final devices = this.devices;
    final userId = this.userId;
    return {
      if (devices != null)
        'devices': devices.map((k, v) => MapEntry(k, v.toJson())),
      if (userId != null) 'user_id': userId,
    };
  }

  /// Each key is an identifier for one of the user's devices.
  Map<String, DeviceInfo>? devices;

  /// The Matrix user ID of the user.
  String? userId;
}

///
@_NameSource('spec')
class ChangePasswordCapability {
  ChangePasswordCapability({
    required this.enabled,
  });

  ChangePasswordCapability.fromJson(Map<String, Object?> json)
      : enabled = json['enabled'] as bool;
  Map<String, Object?> toJson() => {
        'enabled': enabled,
      };

  /// True if the user can change their password, false otherwise.
  bool enabled;
}

/// The stability of the room version.
@_NameSource('rule override generated')
@EnhancedEnum()
enum RoomVersionAvailable {
  @EnhancedEnumValue(name: 'stable')
  stable,
  @EnhancedEnumValue(name: 'unstable')
  unstable
}

///
@_NameSource('spec')
class RoomVersionsCapability {
  RoomVersionsCapability({
    required this.available,
    required this.default$,
  });

  RoomVersionsCapability.fromJson(Map<String, Object?> json)
      : available = (json['available'] as Map<String, Object?>).map((k, v) =>
            MapEntry(k, RoomVersionAvailable.values.fromString(v as String)!)),
        default$ = json['default'] as String;
  Map<String, Object?> toJson() => {
        'available': available.map((k, v) => MapEntry(k, v.name)),
        'default': default$,
      };

  /// A detailed description of the room versions the server supports.
  Map<String, RoomVersionAvailable> available;

  /// The default room version the server is using for new rooms.
  String default$;
}

///
@_NameSource('spec')
class Capabilities {
  Capabilities({
    this.mChangePassword,
    this.mRoomVersions,
    this.additionalProperties = const {},
  });

  Capabilities.fromJson(Map<String, Object?> json)
      : mChangePassword = ((v) => v != null
            ? ChangePasswordCapability.fromJson(v as Map<String, Object?>)
            : null)(json['m.change_password']),
        mRoomVersions = ((v) => v != null
            ? RoomVersionsCapability.fromJson(v as Map<String, Object?>)
            : null)(json['m.room_versions']),
        additionalProperties = Map.fromEntries(json.entries
            .where((e) =>
                !['m.change_password', 'm.room_versions'].contains(e.key))
            .map((e) => MapEntry(e.key, e.value as Map<String, Object?>)));
  Map<String, Object?> toJson() {
    final mChangePassword = this.mChangePassword;
    final mRoomVersions = this.mRoomVersions;
    return {
      ...additionalProperties,
      if (mChangePassword != null)
        'm.change_password': mChangePassword.toJson(),
      if (mRoomVersions != null) 'm.room_versions': mRoomVersions.toJson(),
    };
  }

  /// Capability to indicate if the user can change their password.
  ChangePasswordCapability? mChangePassword;

  /// The room versions the server supports.
  RoomVersionsCapability? mRoomVersions;

  Map<String, Map<String, Object?>> additionalProperties;
}

///
@_NameSource('spec')
class StateEvent {
  StateEvent({
    required this.content,
    this.stateKey,
    required this.type,
  });

  StateEvent.fromJson(Map<String, Object?> json)
      : content = json['content'] as Map<String, Object?>,
        stateKey = ((v) => v != null ? v as String : null)(json['state_key']),
        type = json['type'] as String;
  Map<String, Object?> toJson() {
    final stateKey = this.stateKey;
    return {
      'content': content,
      if (stateKey != null) 'state_key': stateKey,
      'type': type,
    };
  }

  /// The content of the event.
  Map<String, Object?> content;

  /// The state_key of the state event. Defaults to an empty string.
  String? stateKey;

  /// The type of event to send.
  String type;
}

///
@_NameSource('spec')
class Invite3pid {
  Invite3pid({
    required this.address,
    required this.idAccessToken,
    required this.idServer,
    required this.medium,
  });

  Invite3pid.fromJson(Map<String, Object?> json)
      : address = json['address'] as String,
        idAccessToken = json['id_access_token'] as String,
        idServer = json['id_server'] as String,
        medium = json['medium'] as String;
  Map<String, Object?> toJson() => {
        'address': address,
        'id_access_token': idAccessToken,
        'id_server': idServer,
        'medium': medium,
      };

  /// The invitee's third party identifier.
  String address;

  /// An access token previously registered with the identity server. Servers
  /// can treat this as optional to distinguish between r0.5-compatible clients
  /// and this specification version.
  String idAccessToken;

  /// The hostname+port of the identity server which should be used for third party identifier lookups.
  String idServer;

  /// The kind of address being passed in the address field, for example `email`
  /// (see [the list of recognised values](https://spec.matrix.org/unstable/appendices/#3pid-types)).
  String medium;
}

///
@_NameSource('rule override generated')
@EnhancedEnum()
enum CreateRoomPreset {
  @EnhancedEnumValue(name: 'private_chat')
  privateChat,
  @EnhancedEnumValue(name: 'public_chat')
  publicChat,
  @EnhancedEnumValue(name: 'trusted_private_chat')
  trustedPrivateChat
}

///
@_NameSource('generated')
@EnhancedEnum()
enum Visibility {
  @EnhancedEnumValue(name: 'private')
  private,
  @EnhancedEnumValue(name: 'public')
  public
}

/// A client device
@_NameSource('spec')
class Device {
  Device({
    required this.deviceId,
    this.displayName,
    this.lastSeenIp,
    this.lastSeenTs,
  });

  Device.fromJson(Map<String, Object?> json)
      : deviceId = json['device_id'] as String,
        displayName =
            ((v) => v != null ? v as String : null)(json['display_name']),
        lastSeenIp =
            ((v) => v != null ? v as String : null)(json['last_seen_ip']),
        lastSeenTs = ((v) => v != null ? v as int : null)(json['last_seen_ts']);
  Map<String, Object?> toJson() {
    final displayName = this.displayName;
    final lastSeenIp = this.lastSeenIp;
    final lastSeenTs = this.lastSeenTs;
    return {
      'device_id': deviceId,
      if (displayName != null) 'display_name': displayName,
      if (lastSeenIp != null) 'last_seen_ip': lastSeenIp,
      if (lastSeenTs != null) 'last_seen_ts': lastSeenTs,
    };
  }

  /// Identifier of this device.
  String deviceId;

  /// Display name set by the user for this device. Absent if no name has been
  /// set.
  String? displayName;

  /// The IP address where this device was last seen. (May be a few minutes out
  /// of date, for efficiency reasons).
  String? lastSeenIp;

  /// The timestamp (in milliseconds since the unix epoch) when this devices
  /// was last seen. (May be a few minutes out of date, for efficiency
  /// reasons).
  int? lastSeenTs;
}

///
@_NameSource('generated')
class GetRoomIdByAliasResponse {
  GetRoomIdByAliasResponse({
    this.roomId,
    this.servers,
  });

  GetRoomIdByAliasResponse.fromJson(Map<String, Object?> json)
      : roomId = ((v) => v != null ? v as String : null)(json['room_id']),
        servers = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['servers']);
  Map<String, Object?> toJson() {
    final roomId = this.roomId;
    final servers = this.servers;
    return {
      if (roomId != null) 'room_id': roomId,
      if (servers != null) 'servers': servers.map((v) => v).toList(),
    };
  }

  /// The room ID for this room alias.
  String? roomId;

  /// A list of servers that are aware of this room alias.
  List<String>? servers;
}

///
@_NameSource('generated')
class GetEventsResponse {
  GetEventsResponse({
    this.chunk,
    this.end,
    this.start,
  });

  GetEventsResponse.fromJson(Map<String, Object?> json)
      : chunk = ((v) => v != null
            ? (v as List)
                .map((v) => MatrixEvent.fromJson(v as Map<String, Object?>))
                .toList()
            : null)(json['chunk']),
        end = ((v) => v != null ? v as String : null)(json['end']),
        start = ((v) => v != null ? v as String : null)(json['start']);
  Map<String, Object?> toJson() {
    final chunk = this.chunk;
    final end = this.end;
    final start = this.start;
    return {
      if (chunk != null) 'chunk': chunk.map((v) => v.toJson()).toList(),
      if (end != null) 'end': end,
      if (start != null) 'start': start,
    };
  }

  /// An array of events.
  List<MatrixEvent>? chunk;

  /// A token which correlates to the end of `chunk`. This
  /// token should be used in the next request to `/events`.
  String? end;

  /// A token which correlates to the start of `chunk`. This
  /// is usually the same token supplied to `from=`.
  String? start;
}

///
@_NameSource('generated')
class PeekEventsResponse {
  PeekEventsResponse({
    this.chunk,
    this.end,
    this.start,
  });

  PeekEventsResponse.fromJson(Map<String, Object?> json)
      : chunk = ((v) => v != null
            ? (v as List)
                .map((v) => MatrixEvent.fromJson(v as Map<String, Object?>))
                .toList()
            : null)(json['chunk']),
        end = ((v) => v != null ? v as String : null)(json['end']),
        start = ((v) => v != null ? v as String : null)(json['start']);
  Map<String, Object?> toJson() {
    final chunk = this.chunk;
    final end = this.end;
    final start = this.start;
    return {
      if (chunk != null) 'chunk': chunk.map((v) => v.toJson()).toList(),
      if (end != null) 'end': end,
      if (start != null) 'start': start,
    };
  }

  /// An array of events.
  List<MatrixEvent>? chunk;

  /// A token which correlates to the last value in `chunk`. This
  /// token should be used in the next request to `/events`.
  String? end;

  /// A token which correlates to the first value in `chunk`. This
  /// is usually the same token supplied to `from=`.
  String? start;
}

/// A signature of an `m.third_party_invite` token to prove that this user
/// owns a third party identity which has been invited to the room.
@_NameSource('spec')
class ThirdPartySigned {
  ThirdPartySigned({
    required this.mxid,
    required this.sender,
    required this.signatures,
    required this.token,
  });

  ThirdPartySigned.fromJson(Map<String, Object?> json)
      : mxid = json['mxid'] as String,
        sender = json['sender'] as String,
        signatures = (json['signatures'] as Map<String, Object?>).map((k, v) =>
            MapEntry(
                k,
                (v as Map<String, Object?>)
                    .map((k, v) => MapEntry(k, v as String)))),
        token = json['token'] as String;
  Map<String, Object?> toJson() => {
        'mxid': mxid,
        'sender': sender,
        'signatures': signatures
            .map((k, v) => MapEntry(k, v.map((k, v) => MapEntry(k, v)))),
        'token': token,
      };

  /// The Matrix ID of the invitee.
  String mxid;

  /// The Matrix ID of the user who issued the invite.
  String sender;

  /// A signatures object containing a signature of the entire signed object.
  Map<String, Map<String, String>> signatures;

  /// The state key of the m.third_party_invite event.
  String token;
}

///
@_NameSource('generated')
class GetKeysChangesResponse {
  GetKeysChangesResponse({
    this.changed,
    this.left,
  });

  GetKeysChangesResponse.fromJson(Map<String, Object?> json)
      : changed = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['changed']),
        left = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['left']);
  Map<String, Object?> toJson() {
    final changed = this.changed;
    final left = this.left;
    return {
      if (changed != null) 'changed': changed.map((v) => v).toList(),
      if (left != null) 'left': left.map((v) => v).toList(),
    };
  }

  /// The Matrix User IDs of all users who updated their device
  /// identity keys.
  List<String>? changed;

  /// The Matrix User IDs of all users who may have left all
  /// the end-to-end encrypted rooms they previously shared
  /// with the user.
  List<String>? left;
}

///
@_NameSource('generated')
class ClaimKeysResponse {
  ClaimKeysResponse({
    this.failures,
    required this.oneTimeKeys,
  });

  ClaimKeysResponse.fromJson(Map<String, Object?> json)
      : failures = ((v) => v != null
            ? (v as Map<String, Object?>)
                .map((k, v) => MapEntry(k, v as Map<String, Object?>))
            : null)(json['failures']),
        oneTimeKeys = (json['one_time_keys'] as Map<String, Object?>).map(
            (k, v) => MapEntry(
                k,
                (v as Map<String, Object?>)
                    .map((k, v) => MapEntry(k, v as Map<String, Object?>))));
  Map<String, Object?> toJson() {
    final failures = this.failures;
    return {
      if (failures != null) 'failures': failures.map((k, v) => MapEntry(k, v)),
      'one_time_keys': oneTimeKeys
          .map((k, v) => MapEntry(k, v.map((k, v) => MapEntry(k, v)))),
    };
  }

  /// If any remote homeservers could not be reached, they are
  /// recorded here. The names of the properties are the names of
  /// the unreachable servers.
  ///
  /// If the homeserver could be reached, but the user or device
  /// was unknown, no failure is recorded. Instead, the corresponding
  /// user or device is missing from the `one_time_keys` result.
  Map<String, Map<String, Object?>>? failures;

  /// One-time keys for the queried devices. A map from user ID, to a
  /// map from devices to a map from `<algorithm>:<key_id>` to the key object.
  ///
  /// See the [key algorithms](https://spec.matrix.org/unstable/client-server-api/#key-algorithms) section for information
  /// on the Key Object format.
  ///
  /// If necessary, the claimed key might be a fallback key. Fallback
  /// keys are re-used by the server until replaced by the device.
  Map<String, Map<String, Map<String, Object?>>> oneTimeKeys;
}

///
@_NameSource('generated')
class QueryKeysResponse {
  QueryKeysResponse({
    this.deviceKeys,
    this.failures,
    this.masterKeys,
    this.selfSigningKeys,
    this.userSigningKeys,
  });

  QueryKeysResponse.fromJson(Map<String, Object?> json)
      : deviceKeys = ((v) => v != null
            ? (v as Map<String, Object?>).map((k, v) => MapEntry(
                k,
                (v as Map<String, Object?>).map((k, v) => MapEntry(
                    k, MatrixDeviceKeys.fromJson(v as Map<String, Object?>)))))
            : null)(json['device_keys']),
        failures = ((v) => v != null
            ? (v as Map<String, Object?>)
                .map((k, v) => MapEntry(k, v as Map<String, Object?>))
            : null)(json['failures']),
        masterKeys = ((v) => v != null
            ? (v as Map<String, Object?>).map((k, v) => MapEntry(
                k, MatrixCrossSigningKey.fromJson(v as Map<String, Object?>)))
            : null)(json['master_keys']),
        selfSigningKeys = ((v) => v != null
            ? (v as Map<String, Object?>).map((k, v) => MapEntry(
                k, MatrixCrossSigningKey.fromJson(v as Map<String, Object?>)))
            : null)(json['self_signing_keys']),
        userSigningKeys = ((v) => v != null
            ? (v as Map<String, Object?>).map((k, v) => MapEntry(
                k, MatrixCrossSigningKey.fromJson(v as Map<String, Object?>)))
            : null)(json['user_signing_keys']);
  Map<String, Object?> toJson() {
    final deviceKeys = this.deviceKeys;
    final failures = this.failures;
    final masterKeys = this.masterKeys;
    final selfSigningKeys = this.selfSigningKeys;
    final userSigningKeys = this.userSigningKeys;
    return {
      if (deviceKeys != null)
        'device_keys': deviceKeys.map(
            (k, v) => MapEntry(k, v.map((k, v) => MapEntry(k, v.toJson())))),
      if (failures != null) 'failures': failures.map((k, v) => MapEntry(k, v)),
      if (masterKeys != null)
        'master_keys': masterKeys.map((k, v) => MapEntry(k, v.toJson())),
      if (selfSigningKeys != null)
        'self_signing_keys':
            selfSigningKeys.map((k, v) => MapEntry(k, v.toJson())),
      if (userSigningKeys != null)
        'user_signing_keys':
            userSigningKeys.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  /// Information on the queried devices. A map from user ID, to a
  /// map from device ID to device information.  For each device,
  /// the information returned will be the same as uploaded via
  /// `/keys/upload`, with the addition of an `unsigned`
  /// property.
  Map<String, Map<String, MatrixDeviceKeys>>? deviceKeys;

  /// If any remote homeservers could not be reached, they are
  /// recorded here. The names of the properties are the names of
  /// the unreachable servers.
  ///
  /// If the homeserver could be reached, but the user or device
  /// was unknown, no failure is recorded. Instead, the corresponding
  /// user or device is missing from the `device_keys` result.
  Map<String, Map<String, Object?>>? failures;

  /// Information on the master cross-signing keys of the queried users.
  /// A map from user ID, to master key information.  For each key, the
  /// information returned will be the same as uploaded via
  /// `/keys/device_signing/upload`, along with the signatures
  /// uploaded via `/keys/signatures/upload` that the requesting user
  /// is allowed to see.
  Map<String, MatrixCrossSigningKey>? masterKeys;

  /// Information on the self-signing keys of the queried users. A map
  /// from user ID, to self-signing key information.  For each key, the
  /// information returned will be the same as uploaded via
  /// `/keys/device_signing/upload`.
  Map<String, MatrixCrossSigningKey>? selfSigningKeys;

  /// Information on the user-signing key of the user making the
  /// request, if they queried their own device information. A map
  /// from user ID, to user-signing key information.  The
  /// information returned will be the same as uploaded via
  /// `/keys/device_signing/upload`.
  Map<String, MatrixCrossSigningKey>? userSigningKeys;
}

///
@_NameSource('spec')
class LoginFlow {
  LoginFlow({
    this.type,
  });

  LoginFlow.fromJson(Map<String, Object?> json)
      : type = ((v) => v != null ? v as String : null)(json['type']);
  Map<String, Object?> toJson() {
    final type = this.type;
    return {
      if (type != null) 'type': type,
    };
  }

  /// The login type. This is supplied as the `type` when
  /// logging in.
  String? type;
}

///
@_NameSource('rule override generated')
@EnhancedEnum()
enum LoginType {
  @EnhancedEnumValue(name: 'm.login.password')
  mLoginPassword,
  @EnhancedEnumValue(name: 'm.login.token')
  mLoginToken
}

///
@_NameSource('generated')
class LoginResponse {
  LoginResponse({
    required this.accessToken,
    required this.deviceId,
    this.expiresInMs,
    this.homeServer,
    this.refreshToken,
    required this.userId,
    this.wellKnown,
  });

  LoginResponse.fromJson(Map<String, Object?> json)
      : accessToken = json['access_token'] as String,
        deviceId = json['device_id'] as String,
        expiresInMs =
            ((v) => v != null ? v as int : null)(json['expires_in_ms']),
        homeServer =
            ((v) => v != null ? v as String : null)(json['home_server']),
        refreshToken =
            ((v) => v != null ? v as String : null)(json['refresh_token']),
        userId = json['user_id'] as String,
        wellKnown = ((v) => v != null
            ? DiscoveryInformation.fromJson(v as Map<String, Object?>)
            : null)(json['well_known']);
  Map<String, Object?> toJson() {
    final expiresInMs = this.expiresInMs;
    final homeServer = this.homeServer;
    final refreshToken = this.refreshToken;
    final wellKnown = this.wellKnown;
    return {
      'access_token': accessToken,
      'device_id': deviceId,
      if (expiresInMs != null) 'expires_in_ms': expiresInMs,
      if (homeServer != null) 'home_server': homeServer,
      if (refreshToken != null) 'refresh_token': refreshToken,
      'user_id': userId,
      if (wellKnown != null) 'well_known': wellKnown.toJson(),
    };
  }

  /// An access token for the account.
  /// This access token can then be used to authorize other requests.
  String accessToken;

  /// ID of the logged-in device. Will be the same as the
  /// corresponding parameter in the request, if one was specified.
  String deviceId;

  /// The lifetime of the access token, in milliseconds. Once
  /// the access token has expired a new access token can be
  /// obtained by using the provided refresh token. If no
  /// refresh token is provided, the client will need to re-log in
  /// to obtain a new access token. If not given, the client can
  /// assume that the access token will not expire.
  int? expiresInMs;

  /// The server_name of the homeserver on which the account has
  /// been registered.
  ///
  /// **Deprecated**. Clients should extract the server_name from
  /// `user_id` (by splitting at the first colon) if they require
  /// it. Note also that `homeserver` is not spelt this way.
  String? homeServer;

  /// A refresh token for the account. This token can be used to
  /// obtain a new access token when it expires by calling the
  /// `/refresh` endpoint.
  String? refreshToken;

  /// The fully-qualified Matrix ID for the account.
  String userId;

  /// Optional client configuration provided by the server. If present,
  /// clients SHOULD use the provided object to reconfigure themselves,
  /// optionally validating the URLs within. This object takes the same
  /// form as the one returned from .well-known autodiscovery.
  DiscoveryInformation? wellKnown;
}

///
@_NameSource('spec')
class Notification {
  Notification({
    required this.actions,
    required this.event,
    this.profileTag,
    required this.read,
    required this.roomId,
    required this.ts,
  });

  Notification.fromJson(Map<String, Object?> json)
      : actions = (json['actions'] as List).map((v) => v as Object?).toList(),
        event = MatrixEvent.fromJson(json['event'] as Map<String, Object?>),
        profileTag =
            ((v) => v != null ? v as String : null)(json['profile_tag']),
        read = json['read'] as bool,
        roomId = json['room_id'] as String,
        ts = json['ts'] as int;
  Map<String, Object?> toJson() {
    final profileTag = this.profileTag;
    return {
      'actions': actions.map((v) => v).toList(),
      'event': event.toJson(),
      if (profileTag != null) 'profile_tag': profileTag,
      'read': read,
      'room_id': roomId,
      'ts': ts,
    };
  }

  /// The action(s) to perform when the conditions for this rule are met.
  /// See [Push Rules: API](https://spec.matrix.org/unstable/client-server-api/#push-rules-api).
  List<Object?> actions;

  /// The Event object for the event that triggered the notification.
  MatrixEvent event;

  /// The profile tag of the rule that matched this event.
  String? profileTag;

  /// Indicates whether the user has sent a read receipt indicating
  /// that they have read this message.
  bool read;

  /// The ID of the room in which the event was posted.
  String roomId;

  /// The unix timestamp at which the event notification was sent,
  /// in milliseconds.
  int ts;
}

///
@_NameSource('generated')
class GetNotificationsResponse {
  GetNotificationsResponse({
    this.nextToken,
    required this.notifications,
  });

  GetNotificationsResponse.fromJson(Map<String, Object?> json)
      : nextToken = ((v) => v != null ? v as String : null)(json['next_token']),
        notifications = (json['notifications'] as List)
            .map((v) => Notification.fromJson(v as Map<String, Object?>))
            .toList();
  Map<String, Object?> toJson() {
    final nextToken = this.nextToken;
    return {
      if (nextToken != null) 'next_token': nextToken,
      'notifications': notifications.map((v) => v.toJson()).toList(),
    };
  }

  /// The token to supply in the `from` param of the next
  /// `/notifications` request in order to request more
  /// events. If this is absent, there are no more results.
  String? nextToken;

  /// The list of events that triggered notifications.
  List<Notification> notifications;
}

///
@_NameSource('rule override generated')
@EnhancedEnum()
enum PresenceType {
  @EnhancedEnumValue(name: 'offline')
  offline,
  @EnhancedEnumValue(name: 'online')
  online,
  @EnhancedEnumValue(name: 'unavailable')
  unavailable
}

///
@_NameSource('generated')
class GetPresenceResponse {
  GetPresenceResponse({
    this.currentlyActive,
    this.lastActiveAgo,
    required this.presence,
    this.statusMsg,
  });

  GetPresenceResponse.fromJson(Map<String, Object?> json)
      : currentlyActive =
            ((v) => v != null ? v as bool : null)(json['currently_active']),
        lastActiveAgo =
            ((v) => v != null ? v as int : null)(json['last_active_ago']),
        presence = PresenceType.values.fromString(json['presence'] as String)!,
        statusMsg = ((v) => v != null ? v as String : null)(json['status_msg']);
  Map<String, Object?> toJson() {
    final currentlyActive = this.currentlyActive;
    final lastActiveAgo = this.lastActiveAgo;
    final statusMsg = this.statusMsg;
    return {
      if (currentlyActive != null) 'currently_active': currentlyActive,
      if (lastActiveAgo != null) 'last_active_ago': lastActiveAgo,
      'presence': presence.name,
      if (statusMsg != null) 'status_msg': statusMsg,
    };
  }

  /// Whether the user is currently active
  bool? currentlyActive;

  /// The length of time in milliseconds since an action was performed
  /// by this user.
  int? lastActiveAgo;

  /// This user's presence.
  PresenceType presence;

  /// The state message for this user if one was set.
  String? statusMsg;
}

///
@_NameSource('rule override generated')
class ProfileInformation {
  ProfileInformation({
    this.avatarUrl,
    this.displayname,
  });

  ProfileInformation.fromJson(Map<String, Object?> json)
      : avatarUrl = ((v) =>
            v != null ? Uri.parse(v as String) : null)(json['avatar_url']),
        displayname =
            ((v) => v != null ? v as String : null)(json['displayname']);
  Map<String, Object?> toJson() {
    final avatarUrl = this.avatarUrl;
    final displayname = this.displayname;
    return {
      if (avatarUrl != null) 'avatar_url': avatarUrl.toString(),
      if (displayname != null) 'displayname': displayname,
    };
  }

  /// The user's avatar URL if they have set one, otherwise not present.
  Uri? avatarUrl;

  /// The user's display name if they have set one, otherwise not present.
  String? displayname;
}

/// A list of the rooms on the server.
@_NameSource('generated')
class GetPublicRoomsResponse {
  GetPublicRoomsResponse({
    required this.chunk,
    this.nextBatch,
    this.prevBatch,
    this.totalRoomCountEstimate,
  });

  GetPublicRoomsResponse.fromJson(Map<String, Object?> json)
      : chunk = (json['chunk'] as List)
            .map((v) => PublicRoomsChunk.fromJson(v as Map<String, Object?>))
            .toList(),
        nextBatch = ((v) => v != null ? v as String : null)(json['next_batch']),
        prevBatch = ((v) => v != null ? v as String : null)(json['prev_batch']),
        totalRoomCountEstimate = ((v) =>
            v != null ? v as int : null)(json['total_room_count_estimate']);
  Map<String, Object?> toJson() {
    final nextBatch = this.nextBatch;
    final prevBatch = this.prevBatch;
    final totalRoomCountEstimate = this.totalRoomCountEstimate;
    return {
      'chunk': chunk.map((v) => v.toJson()).toList(),
      if (nextBatch != null) 'next_batch': nextBatch,
      if (prevBatch != null) 'prev_batch': prevBatch,
      if (totalRoomCountEstimate != null)
        'total_room_count_estimate': totalRoomCountEstimate,
    };
  }

  /// A paginated chunk of public rooms.
  List<PublicRoomsChunk> chunk;

  /// A pagination token for the response. The absence of this token
  /// means there are no more results to fetch and the client should
  /// stop paginating.
  String? nextBatch;

  /// A pagination token that allows fetching previous results. The
  /// absence of this token means there are no results before this
  /// batch, i.e. this is the first batch.
  String? prevBatch;

  /// An estimate on the total number of public rooms, if the
  /// server has an estimate.
  int? totalRoomCountEstimate;
}

///
@_NameSource('rule override spec')
class PublicRoomQueryFilter {
  PublicRoomQueryFilter({
    this.genericSearchTerm,
    this.roomTypes,
  });

  PublicRoomQueryFilter.fromJson(Map<String, Object?> json)
      : genericSearchTerm = ((v) =>
            v != null ? v as String : null)(json['generic_search_term']),
        roomTypes = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['room_types']);
  Map<String, Object?> toJson() {
    final genericSearchTerm = this.genericSearchTerm;
    final roomTypes = this.roomTypes;
    return {
      if (genericSearchTerm != null) 'generic_search_term': genericSearchTerm,
      if (roomTypes != null) 'room_types': roomTypes.map((v) => v).toList(),
    };
  }

  /// An optional string to search for in the room metadata, e.g. name,
  /// topic, canonical alias, etc.
  String? genericSearchTerm;

  /// An optional list of [room types](https://spec.matrix.org/unstable/client-server-api/#types) to search
  /// for. To include rooms without a room type, specify `null` within this
  /// list. When not specified, all applicable rooms (regardless of type)
  /// are returned.
  List<String>? roomTypes;
}

/// A list of the rooms on the server.
@_NameSource('generated')
class QueryPublicRoomsResponse {
  QueryPublicRoomsResponse({
    required this.chunk,
    this.nextBatch,
    this.prevBatch,
    this.totalRoomCountEstimate,
  });

  QueryPublicRoomsResponse.fromJson(Map<String, Object?> json)
      : chunk = (json['chunk'] as List)
            .map((v) => PublicRoomsChunk.fromJson(v as Map<String, Object?>))
            .toList(),
        nextBatch = ((v) => v != null ? v as String : null)(json['next_batch']),
        prevBatch = ((v) => v != null ? v as String : null)(json['prev_batch']),
        totalRoomCountEstimate = ((v) =>
            v != null ? v as int : null)(json['total_room_count_estimate']);
  Map<String, Object?> toJson() {
    final nextBatch = this.nextBatch;
    final prevBatch = this.prevBatch;
    final totalRoomCountEstimate = this.totalRoomCountEstimate;
    return {
      'chunk': chunk.map((v) => v.toJson()).toList(),
      if (nextBatch != null) 'next_batch': nextBatch,
      if (prevBatch != null) 'prev_batch': prevBatch,
      if (totalRoomCountEstimate != null)
        'total_room_count_estimate': totalRoomCountEstimate,
    };
  }

  /// A paginated chunk of public rooms.
  List<PublicRoomsChunk> chunk;

  /// A pagination token for the response. The absence of this token
  /// means there are no more results to fetch and the client should
  /// stop paginating.
  String? nextBatch;

  /// A pagination token that allows fetching previous results. The
  /// absence of this token means there are no results before this
  /// batch, i.e. this is the first batch.
  String? prevBatch;

  /// An estimate on the total number of public rooms, if the
  /// server has an estimate.
  int? totalRoomCountEstimate;
}

///
@_NameSource('spec')
class PusherData {
  PusherData({
    this.format,
    this.url,
    this.additionalProperties = const {},
  });

  PusherData.fromJson(Map<String, Object?> json)
      : format = ((v) => v != null ? v as String : null)(json['format']),
        url = ((v) => v != null ? Uri.parse(v as String) : null)(json['url']),
        additionalProperties = Map.fromEntries(json.entries
            .where((e) => !['format', 'url'].contains(e.key))
            .map((e) => MapEntry(e.key, e.value)));
  Map<String, Object?> toJson() {
    final format = this.format;
    final url = this.url;
    return {
      ...additionalProperties,
      if (format != null) 'format': format,
      if (url != null) 'url': url.toString(),
    };
  }

  /// The format to use when sending notifications to the Push
  /// Gateway.
  String? format;

  /// Required if `kind` is `http`. The URL to use to send
  /// notifications to.
  Uri? url;

  Map<String, Object?> additionalProperties;
}

///
@_NameSource('spec')
class PusherId {
  PusherId({
    required this.appId,
    required this.pushkey,
  });

  PusherId.fromJson(Map<String, Object?> json)
      : appId = json['app_id'] as String,
        pushkey = json['pushkey'] as String;
  Map<String, Object?> toJson() => {
        'app_id': appId,
        'pushkey': pushkey,
      };

  /// This is a reverse-DNS style identifier for the application.
  /// Max length, 64 chars.
  String appId;

  /// This is a unique identifier for this pusher. See `/set` for
  /// more detail.
  /// Max length, 512 bytes.
  String pushkey;
}

///
@_NameSource('spec')
class Pusher implements PusherId {
  Pusher({
    required this.appId,
    required this.pushkey,
    required this.appDisplayName,
    required this.data,
    required this.deviceDisplayName,
    required this.kind,
    required this.lang,
    this.profileTag,
  });

  Pusher.fromJson(Map<String, Object?> json)
      : appId = json['app_id'] as String,
        pushkey = json['pushkey'] as String,
        appDisplayName = json['app_display_name'] as String,
        data = PusherData.fromJson(json['data'] as Map<String, Object?>),
        deviceDisplayName = json['device_display_name'] as String,
        kind = json['kind'] as String,
        lang = json['lang'] as String,
        profileTag =
            ((v) => v != null ? v as String : null)(json['profile_tag']);
  @override
  Map<String, Object?> toJson() {
    final profileTag = this.profileTag;
    return {
      'app_id': appId,
      'pushkey': pushkey,
      'app_display_name': appDisplayName,
      'data': data.toJson(),
      'device_display_name': deviceDisplayName,
      'kind': kind,
      'lang': lang,
      if (profileTag != null) 'profile_tag': profileTag,
    };
  }

  /// This is a reverse-DNS style identifier for the application.
  /// Max length, 64 chars.
  @override
  String appId;

  /// This is a unique identifier for this pusher. See `/set` for
  /// more detail.
  /// Max length, 512 bytes.
  @override
  String pushkey;

  /// A string that will allow the user to identify what application
  /// owns this pusher.
  String appDisplayName;

  /// A dictionary of information for the pusher implementation
  /// itself.
  PusherData data;

  /// A string that will allow the user to identify what device owns
  /// this pusher.
  String deviceDisplayName;

  /// The kind of pusher. `"http"` is a pusher that
  /// sends HTTP pokes.
  String kind;

  /// The preferred language for receiving notifications (e.g. 'en'
  /// or 'en-US')
  String lang;

  /// This string determines which set of device specific rules this
  /// pusher executes.
  String? profileTag;
}

///
@_NameSource('spec')
class PushCondition {
  PushCondition({
    this.is$,
    this.key,
    required this.kind,
    this.pattern,
  });

  PushCondition.fromJson(Map<String, Object?> json)
      : is$ = ((v) => v != null ? v as String : null)(json['is']),
        key = ((v) => v != null ? v as String : null)(json['key']),
        kind = json['kind'] as String,
        pattern = ((v) => v != null ? v as String : null)(json['pattern']);
  Map<String, Object?> toJson() {
    final is$ = this.is$;
    final key = this.key;
    final pattern = this.pattern;
    return {
      if (is$ != null) 'is': is$,
      if (key != null) 'key': key,
      'kind': kind,
      if (pattern != null) 'pattern': pattern,
    };
  }

  /// Required for `room_member_count` conditions. A decimal integer
  /// optionally prefixed by one of, ==, <, >, >= or <=. A prefix of < matches
  /// rooms where the member count is strictly less than the given number and
  /// so forth. If no prefix is present, this parameter defaults to ==.
  String? is$;

  /// Required for `event_match` conditions. The dot-separated field of the
  /// event to match.
  ///
  /// Required for `sender_notification_permission` conditions. The field in
  /// the power level event the user needs a minimum power level for. Fields
  /// must be specified under the `notifications` property in the power level
  /// event's `content`.
  String? key;

  /// The kind of condition to apply. See [conditions](https://spec.matrix.org/unstable/client-server-api/#conditions) for
  /// more information on the allowed kinds and how they work.
  String kind;

  /// Required for `event_match` conditions. The glob-style pattern to
  /// match against.
  String? pattern;
}

///
@_NameSource('spec')
class PushRule {
  PushRule({
    required this.actions,
    this.conditions,
    required this.default$,
    required this.enabled,
    this.pattern,
    required this.ruleId,
  });

  PushRule.fromJson(Map<String, Object?> json)
      : actions = (json['actions'] as List).map((v) => v as Object?).toList(),
        conditions = ((v) => v != null
            ? (v as List)
                .map((v) => PushCondition.fromJson(v as Map<String, Object?>))
                .toList()
            : null)(json['conditions']),
        default$ = json['default'] as bool,
        enabled = json['enabled'] as bool,
        pattern = ((v) => v != null ? v as String : null)(json['pattern']),
        ruleId = json['rule_id'] as String;
  Map<String, Object?> toJson() {
    final conditions = this.conditions;
    final pattern = this.pattern;
    return {
      'actions': actions.map((v) => v).toList(),
      if (conditions != null)
        'conditions': conditions.map((v) => v.toJson()).toList(),
      'default': default$,
      'enabled': enabled,
      if (pattern != null) 'pattern': pattern,
      'rule_id': ruleId,
    };
  }

  /// The actions to perform when this rule is matched.
  List<Object?> actions;

  /// The conditions that must hold true for an event in order for a rule to be
  /// applied to an event. A rule with no conditions always matches. Only
  /// applicable to `underride` and `override` rules.
  List<PushCondition>? conditions;

  /// Whether this is a default rule, or has been set explicitly.
  bool default$;

  /// Whether the push rule is enabled or not.
  bool enabled;

  /// The glob-style pattern to match against.  Only applicable to `content`
  /// rules.
  String? pattern;

  /// The ID of this rule.
  String ruleId;
}

///
@_NameSource('rule override generated')
class PushRuleSet {
  PushRuleSet({
    this.content,
    this.override,
    this.room,
    this.sender,
    this.underride,
  });

  PushRuleSet.fromJson(Map<String, Object?> json)
      : content = ((v) => v != null
            ? (v as List)
                .map((v) => PushRule.fromJson(v as Map<String, Object?>))
                .toList()
            : null)(json['content']),
        override = ((v) => v != null
            ? (v as List)
                .map((v) => PushRule.fromJson(v as Map<String, Object?>))
                .toList()
            : null)(json['override']),
        room = ((v) => v != null
            ? (v as List)
                .map((v) => PushRule.fromJson(v as Map<String, Object?>))
                .toList()
            : null)(json['room']),
        sender = ((v) => v != null
            ? (v as List)
                .map((v) => PushRule.fromJson(v as Map<String, Object?>))
                .toList()
            : null)(json['sender']),
        underride = ((v) => v != null
            ? (v as List)
                .map((v) => PushRule.fromJson(v as Map<String, Object?>))
                .toList()
            : null)(json['underride']);
  Map<String, Object?> toJson() {
    final content = this.content;
    final override = this.override;
    final room = this.room;
    final sender = this.sender;
    final underride = this.underride;
    return {
      if (content != null) 'content': content.map((v) => v.toJson()).toList(),
      if (override != null)
        'override': override.map((v) => v.toJson()).toList(),
      if (room != null) 'room': room.map((v) => v.toJson()).toList(),
      if (sender != null) 'sender': sender.map((v) => v.toJson()).toList(),
      if (underride != null)
        'underride': underride.map((v) => v.toJson()).toList(),
    };
  }

  ///
  List<PushRule>? content;

  ///
  List<PushRule>? override;

  ///
  List<PushRule>? room;

  ///
  List<PushRule>? sender;

  ///
  List<PushRule>? underride;
}

///
@_NameSource('rule override generated')
@EnhancedEnum()
enum PushRuleKind {
  @EnhancedEnumValue(name: 'content')
  content,
  @EnhancedEnumValue(name: 'override')
  override,
  @EnhancedEnumValue(name: 'room')
  room,
  @EnhancedEnumValue(name: 'sender')
  sender,
  @EnhancedEnumValue(name: 'underride')
  underride
}

///
@_NameSource('generated')
class RefreshResponse {
  RefreshResponse({
    required this.accessToken,
    this.expiresInMs,
    this.refreshToken,
  });

  RefreshResponse.fromJson(Map<String, Object?> json)
      : accessToken = json['access_token'] as String,
        expiresInMs =
            ((v) => v != null ? v as int : null)(json['expires_in_ms']),
        refreshToken =
            ((v) => v != null ? v as String : null)(json['refresh_token']);
  Map<String, Object?> toJson() {
    final expiresInMs = this.expiresInMs;
    final refreshToken = this.refreshToken;
    return {
      'access_token': accessToken,
      if (expiresInMs != null) 'expires_in_ms': expiresInMs,
      if (refreshToken != null) 'refresh_token': refreshToken,
    };
  }

  /// The new access token to use.
  String accessToken;

  /// The lifetime of the access token, in milliseconds. If not
  /// given, the client can assume that the access token will not
  /// expire.
  int? expiresInMs;

  /// The new refresh token to use when the access token needs to
  /// be refreshed again. If not given, the old refresh token can
  /// be re-used.
  String? refreshToken;
}

///
@_NameSource('rule override generated')
@EnhancedEnum()
enum AccountKind {
  @EnhancedEnumValue(name: 'guest')
  guest,
  @EnhancedEnumValue(name: 'user')
  user
}

///
@_NameSource('generated')
class RegisterResponse {
  RegisterResponse({
    this.accessToken,
    this.deviceId,
    this.expiresInMs,
    this.homeServer,
    this.refreshToken,
    required this.userId,
  });

  RegisterResponse.fromJson(Map<String, Object?> json)
      : accessToken =
            ((v) => v != null ? v as String : null)(json['access_token']),
        deviceId = ((v) => v != null ? v as String : null)(json['device_id']),
        expiresInMs =
            ((v) => v != null ? v as int : null)(json['expires_in_ms']),
        homeServer =
            ((v) => v != null ? v as String : null)(json['home_server']),
        refreshToken =
            ((v) => v != null ? v as String : null)(json['refresh_token']),
        userId = json['user_id'] as String;
  Map<String, Object?> toJson() {
    final accessToken = this.accessToken;
    final deviceId = this.deviceId;
    final expiresInMs = this.expiresInMs;
    final homeServer = this.homeServer;
    final refreshToken = this.refreshToken;
    return {
      if (accessToken != null) 'access_token': accessToken,
      if (deviceId != null) 'device_id': deviceId,
      if (expiresInMs != null) 'expires_in_ms': expiresInMs,
      if (homeServer != null) 'home_server': homeServer,
      if (refreshToken != null) 'refresh_token': refreshToken,
      'user_id': userId,
    };
  }

  /// An access token for the account.
  /// This access token can then be used to authorize other requests.
  /// Required if the `inhibit_login` option is false.
  String? accessToken;

  /// ID of the registered device. Will be the same as the
  /// corresponding parameter in the request, if one was specified.
  /// Required if the `inhibit_login` option is false.
  String? deviceId;

  /// The lifetime of the access token, in milliseconds. Once
  /// the access token has expired a new access token can be
  /// obtained by using the provided refresh token. If no
  /// refresh token is provided, the client will need to re-log in
  /// to obtain a new access token. If not given, the client can
  /// assume that the access token will not expire.
  ///
  /// Omitted if the `inhibit_login` option is true.
  int? expiresInMs;

  /// The server_name of the homeserver on which the account has
  /// been registered.
  ///
  /// **Deprecated**. Clients should extract the server_name from
  /// `user_id` (by splitting at the first colon) if they require
  /// it. Note also that `homeserver` is not spelt this way.
  String? homeServer;

  /// A refresh token for the account. This token can be used to
  /// obtain a new access token when it expires by calling the
  /// `/refresh` endpoint.
  ///
  /// Omitted if the `inhibit_login` option is true.
  String? refreshToken;

  /// The fully-qualified Matrix user ID (MXID) that has been registered.
  ///
  /// Any user ID returned by this API must conform to the grammar given in the
  /// [Matrix specification](https://spec.matrix.org/unstable/appendices/#user-identifiers).
  String userId;
}

///
@_NameSource('spec')
class RoomKeysUpdateResponse {
  RoomKeysUpdateResponse({
    required this.count,
    required this.etag,
  });

  RoomKeysUpdateResponse.fromJson(Map<String, Object?> json)
      : count = json['count'] as int,
        etag = json['etag'] as String;
  Map<String, Object?> toJson() => {
        'count': count,
        'etag': etag,
      };

  /// The number of keys stored in the backup
  int count;

  /// The new etag value representing stored keys in the backup.
  /// See `GET /room_keys/version/{version}` for more details.
  String etag;
}

/// The key data
@_NameSource('spec')
class KeyBackupData {
  KeyBackupData({
    required this.firstMessageIndex,
    required this.forwardedCount,
    required this.isVerified,
    required this.sessionData,
  });

  KeyBackupData.fromJson(Map<String, Object?> json)
      : firstMessageIndex = json['first_message_index'] as int,
        forwardedCount = json['forwarded_count'] as int,
        isVerified = json['is_verified'] as bool,
        sessionData = json['session_data'] as Map<String, Object?>;
  Map<String, Object?> toJson() => {
        'first_message_index': firstMessageIndex,
        'forwarded_count': forwardedCount,
        'is_verified': isVerified,
        'session_data': sessionData,
      };

  /// The index of the first message in the session that the key can decrypt.
  int firstMessageIndex;

  /// The number of times this key has been forwarded via key-sharing between devices.
  int forwardedCount;

  /// Whether the device backing up the key verified the device that the key
  /// is from.
  bool isVerified;

  /// Algorithm-dependent data.  See the documentation for the backup
  /// algorithms in [Server-side key backups](https://spec.matrix.org/unstable/client-server-api/#server-side-key-backups) for more information on the
  /// expected format of the data.
  Map<String, Object?> sessionData;
}

/// The backed up keys for a room.
@_NameSource('spec')
class RoomKeyBackup {
  RoomKeyBackup({
    required this.sessions,
  });

  RoomKeyBackup.fromJson(Map<String, Object?> json)
      : sessions = (json['sessions'] as Map<String, Object?>).map((k, v) =>
            MapEntry(k, KeyBackupData.fromJson(v as Map<String, Object?>)));
  Map<String, Object?> toJson() => {
        'sessions': sessions.map((k, v) => MapEntry(k, v.toJson())),
      };

  /// A map of session IDs to key data.
  Map<String, KeyBackupData> sessions;
}

///
@_NameSource('rule override generated')
class RoomKeys {
  RoomKeys({
    required this.rooms,
  });

  RoomKeys.fromJson(Map<String, Object?> json)
      : rooms = (json['rooms'] as Map<String, Object?>).map((k, v) =>
            MapEntry(k, RoomKeyBackup.fromJson(v as Map<String, Object?>)));
  Map<String, Object?> toJson() => {
        'rooms': rooms.map((k, v) => MapEntry(k, v.toJson())),
      };

  /// A map of room IDs to room key backup data.
  Map<String, RoomKeyBackup> rooms;
}

///
@_NameSource('rule override generated')
@EnhancedEnum()
enum BackupAlgorithm {
  @EnhancedEnumValue(name: 'm.megolm_backup.v1.curve25519-aes-sha2')
  mMegolmBackupV1Curve25519AesSha2
}

///
@_NameSource('generated')
class GetRoomKeysVersionCurrentResponse {
  GetRoomKeysVersionCurrentResponse({
    required this.algorithm,
    required this.authData,
    required this.count,
    required this.etag,
    required this.version,
  });

  GetRoomKeysVersionCurrentResponse.fromJson(Map<String, Object?> json)
      : algorithm =
            BackupAlgorithm.values.fromString(json['algorithm'] as String)!,
        authData = json['auth_data'] as Map<String, Object?>,
        count = json['count'] as int,
        etag = json['etag'] as String,
        version = json['version'] as String;
  Map<String, Object?> toJson() => {
        'algorithm': algorithm.name,
        'auth_data': authData,
        'count': count,
        'etag': etag,
        'version': version,
      };

  /// The algorithm used for storing backups.
  BackupAlgorithm algorithm;

  /// Algorithm-dependent data. See the documentation for the backup
  /// algorithms in [Server-side key backups](https://spec.matrix.org/unstable/client-server-api/#server-side-key-backups) for more information on the
  /// expected format of the data.
  Map<String, Object?> authData;

  /// The number of keys stored in the backup.
  int count;

  /// An opaque string representing stored keys in the backup.
  /// Clients can compare it with the `etag` value they received
  /// in the request of their last key storage request.  If not
  /// equal, another client has modified the backup.
  String etag;

  /// The backup version.
  String version;
}

///
@_NameSource('generated')
class GetRoomKeysVersionResponse {
  GetRoomKeysVersionResponse({
    required this.algorithm,
    required this.authData,
    required this.count,
    required this.etag,
    required this.version,
  });

  GetRoomKeysVersionResponse.fromJson(Map<String, Object?> json)
      : algorithm =
            BackupAlgorithm.values.fromString(json['algorithm'] as String)!,
        authData = json['auth_data'] as Map<String, Object?>,
        count = json['count'] as int,
        etag = json['etag'] as String,
        version = json['version'] as String;
  Map<String, Object?> toJson() => {
        'algorithm': algorithm.name,
        'auth_data': authData,
        'count': count,
        'etag': etag,
        'version': version,
      };

  /// The algorithm used for storing backups.
  BackupAlgorithm algorithm;

  /// Algorithm-dependent data. See the documentation for the backup
  /// algorithms in [Server-side key backups](https://spec.matrix.org/unstable/client-server-api/#server-side-key-backups) for more information on the
  /// expected format of the data.
  Map<String, Object?> authData;

  /// The number of keys stored in the backup.
  int count;

  /// An opaque string representing stored keys in the backup.
  /// Clients can compare it with the `etag` value they received
  /// in the request of their last key storage request.  If not
  /// equal, another client has modified the backup.
  String etag;

  /// The backup version.
  String version;
}

/// The events and state surrounding the requested event.
@_NameSource('rule override generated')
class EventContext {
  EventContext({
    this.end,
    this.event,
    this.eventsAfter,
    this.eventsBefore,
    this.start,
    this.state,
  });

  EventContext.fromJson(Map<String, Object?> json)
      : end = ((v) => v != null ? v as String : null)(json['end']),
        event = ((v) => v != null
            ? MatrixEvent.fromJson(v as Map<String, Object?>)
            : null)(json['event']),
        eventsAfter = ((v) => v != null
            ? (v as List)
                .map((v) => MatrixEvent.fromJson(v as Map<String, Object?>))
                .toList()
            : null)(json['events_after']),
        eventsBefore = ((v) => v != null
            ? (v as List)
                .map((v) => MatrixEvent.fromJson(v as Map<String, Object?>))
                .toList()
            : null)(json['events_before']),
        start = ((v) => v != null ? v as String : null)(json['start']),
        state = ((v) => v != null
            ? (v as List)
                .map((v) => MatrixEvent.fromJson(v as Map<String, Object?>))
                .toList()
            : null)(json['state']);
  Map<String, Object?> toJson() {
    final end = this.end;
    final event = this.event;
    final eventsAfter = this.eventsAfter;
    final eventsBefore = this.eventsBefore;
    final start = this.start;
    final state = this.state;
    return {
      if (end != null) 'end': end,
      if (event != null) 'event': event.toJson(),
      if (eventsAfter != null)
        'events_after': eventsAfter.map((v) => v.toJson()).toList(),
      if (eventsBefore != null)
        'events_before': eventsBefore.map((v) => v.toJson()).toList(),
      if (start != null) 'start': start,
      if (state != null) 'state': state.map((v) => v.toJson()).toList(),
    };
  }

  /// A token that can be used to paginate forwards with.
  String? end;

  /// Details of the requested event.
  MatrixEvent? event;

  /// A list of room events that happened just after the
  /// requested event, in chronological order.
  List<MatrixEvent>? eventsAfter;

  /// A list of room events that happened just before the
  /// requested event, in reverse-chronological order.
  List<MatrixEvent>? eventsBefore;

  /// A token that can be used to paginate backwards with.
  String? start;

  /// The state of the room at the last event returned.
  List<MatrixEvent>? state;
}

///
@_NameSource('spec')
class RoomMember {
  RoomMember({
    this.avatarUrl,
    this.displayName,
  });

  RoomMember.fromJson(Map<String, Object?> json)
      : avatarUrl = ((v) =>
            v != null ? Uri.parse(v as String) : null)(json['avatar_url']),
        displayName =
            ((v) => v != null ? v as String : null)(json['display_name']);
  Map<String, Object?> toJson() {
    final avatarUrl = this.avatarUrl;
    final displayName = this.displayName;
    return {
      if (avatarUrl != null) 'avatar_url': avatarUrl.toString(),
      if (displayName != null) 'display_name': displayName,
    };
  }

  /// The mxc avatar url of the user this object is representing.
  Uri? avatarUrl;

  /// The display name of the user this object is representing.
  String? displayName;
}

///
@_NameSource('(generated, rule override generated)')
@EnhancedEnum()
enum Membership {
  @EnhancedEnumValue(name: 'ban')
  ban,
  @EnhancedEnumValue(name: 'invite')
  invite,
  @EnhancedEnumValue(name: 'join')
  join,
  @EnhancedEnumValue(name: 'knock')
  knock,
  @EnhancedEnumValue(name: 'leave')
  leave
}

/// A list of messages with a new token to request more.
@_NameSource('generated')
class GetRoomEventsResponse {
  GetRoomEventsResponse({
    required this.chunk,
    this.end,
    required this.start,
    this.state,
  });

  GetRoomEventsResponse.fromJson(Map<String, Object?> json)
      : chunk = (json['chunk'] as List)
            .map((v) => MatrixEvent.fromJson(v as Map<String, Object?>))
            .toList(),
        end = ((v) => v != null ? v as String : null)(json['end']),
        start = json['start'] as String,
        state = ((v) => v != null
            ? (v as List)
                .map((v) => MatrixEvent.fromJson(v as Map<String, Object?>))
                .toList()
            : null)(json['state']);
  Map<String, Object?> toJson() {
    final end = this.end;
    final state = this.state;
    return {
      'chunk': chunk.map((v) => v.toJson()).toList(),
      if (end != null) 'end': end,
      'start': start,
      if (state != null) 'state': state.map((v) => v.toJson()).toList(),
    };
  }

  /// A list of room events. The order depends on the `dir` parameter.
  /// For `dir=b` events will be in reverse-chronological order,
  /// for `dir=f` in chronological order. (The exact definition of `chronological`
  /// is dependent on the server implementation.)
  ///
  /// Note that an empty `chunk` does not *necessarily* imply that no more events
  /// are available. Clients should continue to paginate until no `end` property
  /// is returned.
  List<MatrixEvent> chunk;

  /// A token corresponding to the end of `chunk`. This token can be passed
  /// back to this endpoint to request further events.
  ///
  /// If no further events are available (either because we have
  /// reached the start of the timeline, or because the user does
  /// not have permission to see any more events), this property
  /// is omitted from the response.
  String? end;

  /// A token corresponding to the start of `chunk`. This will be the same as
  /// the value given in `from`.
  String start;

  /// A list of state events relevant to showing the `chunk`. For example, if
  /// `lazy_load_members` is enabled in the filter then this may contain
  /// the membership events for the senders of events in the `chunk`.
  ///
  /// Unless `include_redundant_members` is `true`, the server
  /// may remove membership events which would have already been
  /// sent to the client in prior calls to this endpoint, assuming
  /// the membership of those members has not changed.
  List<MatrixEvent>? state;
}

///
@_NameSource('generated')
@EnhancedEnum()
enum ReceiptType {
  @EnhancedEnumValue(name: 'm.fully_read')
  mFullyRead,
  @EnhancedEnumValue(name: 'm.read')
  mRead,
  @EnhancedEnumValue(name: 'm.read.private')
  mReadPrivate
}

///
@_NameSource('spec')
class IncludeEventContext {
  IncludeEventContext({
    this.afterLimit,
    this.beforeLimit,
    this.includeProfile,
  });

  IncludeEventContext.fromJson(Map<String, Object?> json)
      : afterLimit = ((v) => v != null ? v as int : null)(json['after_limit']),
        beforeLimit =
            ((v) => v != null ? v as int : null)(json['before_limit']),
        includeProfile =
            ((v) => v != null ? v as bool : null)(json['include_profile']);
  Map<String, Object?> toJson() {
    final afterLimit = this.afterLimit;
    final beforeLimit = this.beforeLimit;
    final includeProfile = this.includeProfile;
    return {
      if (afterLimit != null) 'after_limit': afterLimit,
      if (beforeLimit != null) 'before_limit': beforeLimit,
      if (includeProfile != null) 'include_profile': includeProfile,
    };
  }

  /// How many events after the result are
  /// returned. By default, this is `5`.
  int? afterLimit;

  /// How many events before the result are
  /// returned. By default, this is `5`.
  int? beforeLimit;

  /// Requests that the server returns the
  /// historic profile information for the users
  /// that sent the events that were returned.
  /// By default, this is `false`.
  bool? includeProfile;
}

///
@_NameSource('spec')
class EventFilter {
  EventFilter({
    this.limit,
    this.notSenders,
    this.notTypes,
    this.senders,
    this.types,
  });

  EventFilter.fromJson(Map<String, Object?> json)
      : limit = ((v) => v != null ? v as int : null)(json['limit']),
        notSenders = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['not_senders']),
        notTypes = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['not_types']),
        senders = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['senders']),
        types = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['types']);
  Map<String, Object?> toJson() {
    final limit = this.limit;
    final notSenders = this.notSenders;
    final notTypes = this.notTypes;
    final senders = this.senders;
    final types = this.types;
    return {
      if (limit != null) 'limit': limit,
      if (notSenders != null) 'not_senders': notSenders.map((v) => v).toList(),
      if (notTypes != null) 'not_types': notTypes.map((v) => v).toList(),
      if (senders != null) 'senders': senders.map((v) => v).toList(),
      if (types != null) 'types': types.map((v) => v).toList(),
    };
  }

  /// The maximum number of events to return.
  int? limit;

  /// A list of sender IDs to exclude. If this list is absent then no senders are excluded. A matching sender will be excluded even if it is listed in the `'senders'` filter.
  List<String>? notSenders;

  /// A list of event types to exclude. If this list is absent then no event types are excluded. A matching type will be excluded even if it is listed in the `'types'` filter. A '*' can be used as a wildcard to match any sequence of characters.
  List<String>? notTypes;

  /// A list of senders IDs to include. If this list is absent then all senders are included.
  List<String>? senders;

  /// A list of event types to include. If this list is absent then all event types are included. A `'*'` can be used as a wildcard to match any sequence of characters.
  List<String>? types;
}

///
@_NameSource('spec')
class RoomEventFilter {
  RoomEventFilter({
    this.containsUrl,
    this.includeRedundantMembers,
    this.lazyLoadMembers,
    this.notRooms,
    this.rooms,
    this.unreadThreadNotifications,
  });

  RoomEventFilter.fromJson(Map<String, Object?> json)
      : containsUrl =
            ((v) => v != null ? v as bool : null)(json['contains_url']),
        includeRedundantMembers = ((v) =>
            v != null ? v as bool : null)(json['include_redundant_members']),
        lazyLoadMembers =
            ((v) => v != null ? v as bool : null)(json['lazy_load_members']),
        notRooms = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['not_rooms']),
        rooms = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['rooms']),
        unreadThreadNotifications = ((v) =>
            v != null ? v as bool : null)(json['unread_thread_notifications']);
  Map<String, Object?> toJson() {
    final containsUrl = this.containsUrl;
    final includeRedundantMembers = this.includeRedundantMembers;
    final lazyLoadMembers = this.lazyLoadMembers;
    final notRooms = this.notRooms;
    final rooms = this.rooms;
    final unreadThreadNotifications = this.unreadThreadNotifications;
    return {
      if (containsUrl != null) 'contains_url': containsUrl,
      if (includeRedundantMembers != null)
        'include_redundant_members': includeRedundantMembers,
      if (lazyLoadMembers != null) 'lazy_load_members': lazyLoadMembers,
      if (notRooms != null) 'not_rooms': notRooms.map((v) => v).toList(),
      if (rooms != null) 'rooms': rooms.map((v) => v).toList(),
      if (unreadThreadNotifications != null)
        'unread_thread_notifications': unreadThreadNotifications,
    };
  }

  /// If `true`, includes only events with a `url` key in their content. If `false`, excludes those events. If omitted, `url` key is not considered for filtering.
  bool? containsUrl;

  /// If `true`, sends all membership events for all events, even if they have already
  /// been sent to the client. Does not
  /// apply unless `lazy_load_members` is `true`. See
  /// [Lazy-loading room members](https://spec.matrix.org/unstable/client-server-api/#lazy-loading-room-members)
  /// for more information. Defaults to `false`.
  bool? includeRedundantMembers;

  /// If `true`, enables lazy-loading of membership events. See
  /// [Lazy-loading room members](https://spec.matrix.org/unstable/client-server-api/#lazy-loading-room-members)
  /// for more information. Defaults to `false`.
  bool? lazyLoadMembers;

  /// A list of room IDs to exclude. If this list is absent then no rooms are excluded. A matching room will be excluded even if it is listed in the `'rooms'` filter.
  List<String>? notRooms;

  /// A list of room IDs to include. If this list is absent then all rooms are included.
  List<String>? rooms;

  /// If `true`, enables per-[thread](https://spec.matrix.org/unstable/client-server-api/#threading) notification
  /// counts. Only applies to the `/sync` endpoint. Defaults to `false`.
  bool? unreadThreadNotifications;
}

///
@_NameSource('rule override generated')
class SearchFilter implements EventFilter, RoomEventFilter {
  SearchFilter({
    this.limit,
    this.notSenders,
    this.notTypes,
    this.senders,
    this.types,
    this.containsUrl,
    this.includeRedundantMembers,
    this.lazyLoadMembers,
    this.notRooms,
    this.rooms,
    this.unreadThreadNotifications,
  });

  SearchFilter.fromJson(Map<String, Object?> json)
      : limit = ((v) => v != null ? v as int : null)(json['limit']),
        notSenders = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['not_senders']),
        notTypes = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['not_types']),
        senders = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['senders']),
        types = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['types']),
        containsUrl =
            ((v) => v != null ? v as bool : null)(json['contains_url']),
        includeRedundantMembers = ((v) =>
            v != null ? v as bool : null)(json['include_redundant_members']),
        lazyLoadMembers =
            ((v) => v != null ? v as bool : null)(json['lazy_load_members']),
        notRooms = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['not_rooms']),
        rooms = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['rooms']),
        unreadThreadNotifications = ((v) =>
            v != null ? v as bool : null)(json['unread_thread_notifications']);
  @override
  Map<String, Object?> toJson() {
    final limit = this.limit;
    final notSenders = this.notSenders;
    final notTypes = this.notTypes;
    final senders = this.senders;
    final types = this.types;
    final containsUrl = this.containsUrl;
    final includeRedundantMembers = this.includeRedundantMembers;
    final lazyLoadMembers = this.lazyLoadMembers;
    final notRooms = this.notRooms;
    final rooms = this.rooms;
    final unreadThreadNotifications = this.unreadThreadNotifications;
    return {
      if (limit != null) 'limit': limit,
      if (notSenders != null) 'not_senders': notSenders.map((v) => v).toList(),
      if (notTypes != null) 'not_types': notTypes.map((v) => v).toList(),
      if (senders != null) 'senders': senders.map((v) => v).toList(),
      if (types != null) 'types': types.map((v) => v).toList(),
      if (containsUrl != null) 'contains_url': containsUrl,
      if (includeRedundantMembers != null)
        'include_redundant_members': includeRedundantMembers,
      if (lazyLoadMembers != null) 'lazy_load_members': lazyLoadMembers,
      if (notRooms != null) 'not_rooms': notRooms.map((v) => v).toList(),
      if (rooms != null) 'rooms': rooms.map((v) => v).toList(),
      if (unreadThreadNotifications != null)
        'unread_thread_notifications': unreadThreadNotifications,
    };
  }

  /// The maximum number of events to return.
  @override
  int? limit;

  /// A list of sender IDs to exclude. If this list is absent then no senders are excluded. A matching sender will be excluded even if it is listed in the `'senders'` filter.
  @override
  List<String>? notSenders;

  /// A list of event types to exclude. If this list is absent then no event types are excluded. A matching type will be excluded even if it is listed in the `'types'` filter. A '*' can be used as a wildcard to match any sequence of characters.
  @override
  List<String>? notTypes;

  /// A list of senders IDs to include. If this list is absent then all senders are included.
  @override
  List<String>? senders;

  /// A list of event types to include. If this list is absent then all event types are included. A `'*'` can be used as a wildcard to match any sequence of characters.
  @override
  List<String>? types;

  /// If `true`, includes only events with a `url` key in their content. If `false`, excludes those events. If omitted, `url` key is not considered for filtering.
  @override
  bool? containsUrl;

  /// If `true`, sends all membership events for all events, even if they have already
  /// been sent to the client. Does not
  /// apply unless `lazy_load_members` is `true`. See
  /// [Lazy-loading room members](https://spec.matrix.org/unstable/client-server-api/#lazy-loading-room-members)
  /// for more information. Defaults to `false`.
  @override
  bool? includeRedundantMembers;

  /// If `true`, enables lazy-loading of membership events. See
  /// [Lazy-loading room members](https://spec.matrix.org/unstable/client-server-api/#lazy-loading-room-members)
  /// for more information. Defaults to `false`.
  @override
  bool? lazyLoadMembers;

  /// A list of room IDs to exclude. If this list is absent then no rooms are excluded. A matching room will be excluded even if it is listed in the `'rooms'` filter.
  @override
  List<String>? notRooms;

  /// A list of room IDs to include. If this list is absent then all rooms are included.
  @override
  List<String>? rooms;

  /// If `true`, enables per-[thread](https://spec.matrix.org/unstable/client-server-api/#threading) notification
  /// counts. Only applies to the `/sync` endpoint. Defaults to `false`.
  @override
  bool? unreadThreadNotifications;
}

///
@_NameSource('rule override generated')
@EnhancedEnum()
enum GroupKey {
  @EnhancedEnumValue(name: 'room_id')
  roomId,
  @EnhancedEnumValue(name: 'sender')
  sender
}

/// Configuration for group.
@_NameSource('spec')
class Group {
  Group({
    this.key,
  });

  Group.fromJson(Map<String, Object?> json)
      : key = ((v) => v != null
            ? GroupKey.values.fromString(v as String)!
            : null)(json['key']);
  Map<String, Object?> toJson() {
    final key = this.key;
    return {
      if (key != null) 'key': key.name,
    };
  }

  /// Key that defines the group.
  GroupKey? key;
}

///
@_NameSource('spec')
class Groupings {
  Groupings({
    this.groupBy,
  });

  Groupings.fromJson(Map<String, Object?> json)
      : groupBy = ((v) => v != null
            ? (v as List)
                .map((v) => Group.fromJson(v as Map<String, Object?>))
                .toList()
            : null)(json['group_by']);
  Map<String, Object?> toJson() {
    final groupBy = this.groupBy;
    return {
      if (groupBy != null) 'group_by': groupBy.map((v) => v.toJson()).toList(),
    };
  }

  /// List of groups to request.
  List<Group>? groupBy;
}

///
@_NameSource('rule override generated')
@EnhancedEnum()
enum KeyKind {
  @EnhancedEnumValue(name: 'content.body')
  contentBody,
  @EnhancedEnumValue(name: 'content.name')
  contentName,
  @EnhancedEnumValue(name: 'content.topic')
  contentTopic
}

///
@_NameSource('rule override generated')
@EnhancedEnum()
enum SearchOrder {
  @EnhancedEnumValue(name: 'rank')
  rank,
  @EnhancedEnumValue(name: 'recent')
  recent
}

///
@_NameSource('spec')
class RoomEventsCriteria {
  RoomEventsCriteria({
    this.eventContext,
    this.filter,
    this.groupings,
    this.includeState,
    this.keys,
    this.orderBy,
    required this.searchTerm,
  });

  RoomEventsCriteria.fromJson(Map<String, Object?> json)
      : eventContext = ((v) => v != null
            ? IncludeEventContext.fromJson(v as Map<String, Object?>)
            : null)(json['event_context']),
        filter = ((v) => v != null
            ? SearchFilter.fromJson(v as Map<String, Object?>)
            : null)(json['filter']),
        groupings = ((v) => v != null
            ? Groupings.fromJson(v as Map<String, Object?>)
            : null)(json['groupings']),
        includeState =
            ((v) => v != null ? v as bool : null)(json['include_state']),
        keys = ((v) => v != null
            ? (v as List)
                .map((v) => KeyKind.values.fromString(v as String)!)
                .toList()
            : null)(json['keys']),
        orderBy = ((v) => v != null
            ? SearchOrder.values.fromString(v as String)!
            : null)(json['order_by']),
        searchTerm = json['search_term'] as String;
  Map<String, Object?> toJson() {
    final eventContext = this.eventContext;
    final filter = this.filter;
    final groupings = this.groupings;
    final includeState = this.includeState;
    final keys = this.keys;
    final orderBy = this.orderBy;
    return {
      if (eventContext != null) 'event_context': eventContext.toJson(),
      if (filter != null) 'filter': filter.toJson(),
      if (groupings != null) 'groupings': groupings.toJson(),
      if (includeState != null) 'include_state': includeState,
      if (keys != null) 'keys': keys.map((v) => v.name).toList(),
      if (orderBy != null) 'order_by': orderBy.name,
      'search_term': searchTerm,
    };
  }

  /// Configures whether any context for the events
  /// returned are included in the response.
  IncludeEventContext? eventContext;

  /// This takes a [filter](https://spec.matrix.org/unstable/client-server-api/#filtering).
  SearchFilter? filter;

  /// Requests that the server partitions the result set
  /// based on the provided list of keys.
  Groupings? groupings;

  /// Requests the server return the current state for
  /// each room returned.
  bool? includeState;

  /// The keys to search. Defaults to all.
  List<KeyKind>? keys;

  /// The order in which to search for results.
  /// By default, this is `"rank"`.
  SearchOrder? orderBy;

  /// The string to search events for
  String searchTerm;
}

///
@_NameSource('spec')
class Categories {
  Categories({
    this.roomEvents,
  });

  Categories.fromJson(Map<String, Object?> json)
      : roomEvents = ((v) => v != null
            ? RoomEventsCriteria.fromJson(v as Map<String, Object?>)
            : null)(json['room_events']);
  Map<String, Object?> toJson() {
    final roomEvents = this.roomEvents;
    return {
      if (roomEvents != null) 'room_events': roomEvents.toJson(),
    };
  }

  /// Mapping of category name to search criteria.
  RoomEventsCriteria? roomEvents;
}

/// The results for a particular group value.
@_NameSource('spec')
class GroupValue {
  GroupValue({
    this.nextBatch,
    this.order,
    this.results,
  });

  GroupValue.fromJson(Map<String, Object?> json)
      : nextBatch = ((v) => v != null ? v as String : null)(json['next_batch']),
        order = ((v) => v != null ? v as int : null)(json['order']),
        results = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['results']);
  Map<String, Object?> toJson() {
    final nextBatch = this.nextBatch;
    final order = this.order;
    final results = this.results;
    return {
      if (nextBatch != null) 'next_batch': nextBatch,
      if (order != null) 'order': order,
      if (results != null) 'results': results.map((v) => v).toList(),
    };
  }

  /// Token that can be used to get the next batch
  /// of results in the group, by passing as the
  /// `next_batch` parameter to the next call. If
  /// this field is absent, there are no more
  /// results in this group.
  String? nextBatch;

  /// Key that can be used to order different
  /// groups.
  int? order;

  /// Which results are in this group.
  List<String>? results;
}

///
@_NameSource('spec')
class UserProfile {
  UserProfile({
    this.avatarUrl,
    this.displayname,
  });

  UserProfile.fromJson(Map<String, Object?> json)
      : avatarUrl = ((v) =>
            v != null ? Uri.parse(v as String) : null)(json['avatar_url']),
        displayname =
            ((v) => v != null ? v as String : null)(json['displayname']);
  Map<String, Object?> toJson() {
    final avatarUrl = this.avatarUrl;
    final displayname = this.displayname;
    return {
      if (avatarUrl != null) 'avatar_url': avatarUrl.toString(),
      if (displayname != null) 'displayname': displayname,
    };
  }

  ///
  Uri? avatarUrl;

  ///
  String? displayname;
}

///
@_NameSource('rule override spec')
class SearchResultsEventContext {
  SearchResultsEventContext({
    this.end,
    this.eventsAfter,
    this.eventsBefore,
    this.profileInfo,
    this.start,
  });

  SearchResultsEventContext.fromJson(Map<String, Object?> json)
      : end = ((v) => v != null ? v as String : null)(json['end']),
        eventsAfter = ((v) => v != null
            ? (v as List)
                .map((v) => MatrixEvent.fromJson(v as Map<String, Object?>))
                .toList()
            : null)(json['events_after']),
        eventsBefore = ((v) => v != null
            ? (v as List)
                .map((v) => MatrixEvent.fromJson(v as Map<String, Object?>))
                .toList()
            : null)(json['events_before']),
        profileInfo = ((v) => v != null
            ? (v as Map<String, Object?>).map((k, v) =>
                MapEntry(k, UserProfile.fromJson(v as Map<String, Object?>)))
            : null)(json['profile_info']),
        start = ((v) => v != null ? v as String : null)(json['start']);
  Map<String, Object?> toJson() {
    final end = this.end;
    final eventsAfter = this.eventsAfter;
    final eventsBefore = this.eventsBefore;
    final profileInfo = this.profileInfo;
    final start = this.start;
    return {
      if (end != null) 'end': end,
      if (eventsAfter != null)
        'events_after': eventsAfter.map((v) => v.toJson()).toList(),
      if (eventsBefore != null)
        'events_before': eventsBefore.map((v) => v.toJson()).toList(),
      if (profileInfo != null)
        'profile_info': profileInfo.map((k, v) => MapEntry(k, v.toJson())),
      if (start != null) 'start': start,
    };
  }

  /// Pagination token for the end of the chunk
  String? end;

  /// Events just after the result.
  List<MatrixEvent>? eventsAfter;

  /// Events just before the result.
  List<MatrixEvent>? eventsBefore;

  /// The historic profile information of the
  /// users that sent the events returned.
  ///
  /// The `string` key is the user ID for which
  /// the profile belongs to.
  Map<String, UserProfile>? profileInfo;

  /// Pagination token for the start of the chunk
  String? start;
}

/// The result object.
@_NameSource('spec')
class Result {
  Result({
    this.context,
    this.rank,
    this.result,
  });

  Result.fromJson(Map<String, Object?> json)
      : context = ((v) => v != null
            ? SearchResultsEventContext.fromJson(v as Map<String, Object?>)
            : null)(json['context']),
        rank = ((v) => v != null ? (v as num).toDouble() : null)(json['rank']),
        result = ((v) => v != null
            ? MatrixEvent.fromJson(v as Map<String, Object?>)
            : null)(json['result']);
  Map<String, Object?> toJson() {
    final context = this.context;
    final rank = this.rank;
    final result = this.result;
    return {
      if (context != null) 'context': context.toJson(),
      if (rank != null) 'rank': rank,
      if (result != null) 'result': result.toJson(),
    };
  }

  /// Context for result, if requested.
  SearchResultsEventContext? context;

  /// A number that describes how closely this result matches the search. Higher is closer.
  double? rank;

  /// The event that matched.
  MatrixEvent? result;
}

///
@_NameSource('spec')
class ResultRoomEvents {
  ResultRoomEvents({
    this.count,
    this.groups,
    this.highlights,
    this.nextBatch,
    this.results,
    this.state,
  });

  ResultRoomEvents.fromJson(Map<String, Object?> json)
      : count = ((v) => v != null ? v as int : null)(json['count']),
        groups = ((v) => v != null
            ? (v as Map<String, Object?>).map((k, v) => MapEntry(
                k,
                (v as Map<String, Object?>).map((k, v) => MapEntry(
                    k, GroupValue.fromJson(v as Map<String, Object?>)))))
            : null)(json['groups']),
        highlights = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['highlights']),
        nextBatch = ((v) => v != null ? v as String : null)(json['next_batch']),
        results = ((v) => v != null
            ? (v as List)
                .map((v) => Result.fromJson(v as Map<String, Object?>))
                .toList()
            : null)(json['results']),
        state = ((v) => v != null
            ? (v as Map<String, Object?>).map((k, v) => MapEntry(
                k,
                (v as List)
                    .map((v) => MatrixEvent.fromJson(v as Map<String, Object?>))
                    .toList()))
            : null)(json['state']);
  Map<String, Object?> toJson() {
    final count = this.count;
    final groups = this.groups;
    final highlights = this.highlights;
    final nextBatch = this.nextBatch;
    final results = this.results;
    final state = this.state;
    return {
      if (count != null) 'count': count,
      if (groups != null)
        'groups': groups.map(
            (k, v) => MapEntry(k, v.map((k, v) => MapEntry(k, v.toJson())))),
      if (highlights != null) 'highlights': highlights.map((v) => v).toList(),
      if (nextBatch != null) 'next_batch': nextBatch,
      if (results != null) 'results': results.map((v) => v.toJson()).toList(),
      if (state != null)
        'state':
            state.map((k, v) => MapEntry(k, v.map((v) => v.toJson()).toList())),
    };
  }

  /// An approximate count of the total number of results found.
  int? count;

  /// Any groups that were requested.
  ///
  /// The outer `string` key is the group key requested (eg: `room_id`
  /// or `sender`). The inner `string` key is the grouped value (eg:
  /// a room's ID or a user's ID).
  Map<String, Map<String, GroupValue>>? groups;

  /// List of words which should be highlighted, useful for stemming which may change the query terms.
  List<String>? highlights;

  /// Token that can be used to get the next batch of
  /// results, by passing as the `next_batch` parameter to
  /// the next call. If this field is absent, there are no
  /// more results.
  String? nextBatch;

  /// List of results in the requested order.
  List<Result>? results;

  /// The current state for every room in the results.
  /// This is included if the request had the
  /// `include_state` key set with a value of `true`.
  ///
  /// The `string` key is the room ID for which the `State
  /// Event` array belongs to.
  Map<String, List<MatrixEvent>>? state;
}

///
@_NameSource('spec')
class ResultCategories {
  ResultCategories({
    this.roomEvents,
  });

  ResultCategories.fromJson(Map<String, Object?> json)
      : roomEvents = ((v) => v != null
            ? ResultRoomEvents.fromJson(v as Map<String, Object?>)
            : null)(json['room_events']);
  Map<String, Object?> toJson() {
    final roomEvents = this.roomEvents;
    return {
      if (roomEvents != null) 'room_events': roomEvents.toJson(),
    };
  }

  /// Mapping of category name to search criteria.
  ResultRoomEvents? roomEvents;
}

///
@_NameSource('rule override spec')
class SearchResults {
  SearchResults({
    required this.searchCategories,
  });

  SearchResults.fromJson(Map<String, Object?> json)
      : searchCategories = ResultCategories.fromJson(
            json['search_categories'] as Map<String, Object?>);
  Map<String, Object?> toJson() => {
        'search_categories': searchCategories.toJson(),
      };

  /// Describes which categories to search in and their criteria.
  ResultCategories searchCategories;
}

///
@_NameSource('spec')
class Location {
  Location({
    required this.alias,
    required this.fields,
    required this.protocol,
  });

  Location.fromJson(Map<String, Object?> json)
      : alias = json['alias'] as String,
        fields = json['fields'] as Map<String, Object?>,
        protocol = json['protocol'] as String;
  Map<String, Object?> toJson() => {
        'alias': alias,
        'fields': fields,
        'protocol': protocol,
      };

  /// An alias for a matrix room.
  String alias;

  /// Information used to identify this third party location.
  Map<String, Object?> fields;

  /// The protocol ID that the third party location is a part of.
  String protocol;
}

/// Definition of valid values for a field.
@_NameSource('spec')
class FieldType {
  FieldType({
    required this.placeholder,
    required this.regexp,
  });

  FieldType.fromJson(Map<String, Object?> json)
      : placeholder = json['placeholder'] as String,
        regexp = json['regexp'] as String;
  Map<String, Object?> toJson() => {
        'placeholder': placeholder,
        'regexp': regexp,
      };

  /// An placeholder serving as a valid example of the field value.
  String placeholder;

  /// A regular expression for validation of a field's value. This may be relatively
  /// coarse to verify the value as the application service providing this protocol
  /// may apply additional validation or filtering.
  String regexp;
}

///
@_NameSource('spec')
class ProtocolInstance {
  ProtocolInstance({
    required this.desc,
    required this.fields,
    this.icon,
    required this.networkId,
  });

  ProtocolInstance.fromJson(Map<String, Object?> json)
      : desc = json['desc'] as String,
        fields = json['fields'] as Map<String, Object?>,
        icon = ((v) => v != null ? v as String : null)(json['icon']),
        networkId = json['network_id'] as String;
  Map<String, Object?> toJson() {
    final icon = this.icon;
    return {
      'desc': desc,
      'fields': fields,
      if (icon != null) 'icon': icon,
      'network_id': networkId,
    };
  }

  /// A human-readable description for the protocol, such as the name.
  String desc;

  /// Preset values for `fields` the client may use to search by.
  Map<String, Object?> fields;

  /// An optional content URI representing the protocol. Overrides the one provided
  /// at the higher level Protocol object.
  String? icon;

  /// A unique identifier across all instances.
  String networkId;
}

///
@_NameSource('spec')
class Protocol {
  Protocol({
    required this.fieldTypes,
    required this.icon,
    required this.instances,
    required this.locationFields,
    required this.userFields,
  });

  Protocol.fromJson(Map<String, Object?> json)
      : fieldTypes = (json['field_types'] as Map<String, Object?>).map((k, v) =>
            MapEntry(k, FieldType.fromJson(v as Map<String, Object?>))),
        icon = json['icon'] as String,
        instances = (json['instances'] as List)
            .map((v) => ProtocolInstance.fromJson(v as Map<String, Object?>))
            .toList(),
        locationFields =
            (json['location_fields'] as List).map((v) => v as String).toList(),
        userFields =
            (json['user_fields'] as List).map((v) => v as String).toList();
  Map<String, Object?> toJson() => {
        'field_types': fieldTypes.map((k, v) => MapEntry(k, v.toJson())),
        'icon': icon,
        'instances': instances.map((v) => v.toJson()).toList(),
        'location_fields': locationFields.map((v) => v).toList(),
        'user_fields': userFields.map((v) => v).toList(),
      };

  /// The type definitions for the fields defined in the `user_fields` and
  /// `location_fields`. Each entry in those arrays MUST have an entry here. The
  /// `string` key for this object is field name itself.
  ///
  /// May be an empty object if no fields are defined.
  Map<String, FieldType> fieldTypes;

  /// A content URI representing an icon for the third party protocol.
  String icon;

  /// A list of objects representing independent instances of configuration.
  /// For example, multiple networks on IRC if multiple are provided by the
  /// same application service.
  List<ProtocolInstance> instances;

  /// Fields which may be used to identify a third party location. These should be
  /// ordered to suggest the way that entities may be grouped, where higher
  /// groupings are ordered first. For example, the name of a network should be
  /// searched before the name of a channel.
  List<String> locationFields;

  /// Fields which may be used to identify a third party user. These should be
  /// ordered to suggest the way that entities may be grouped, where higher
  /// groupings are ordered first. For example, the name of a network should be
  /// searched before the nickname of a user.
  List<String> userFields;
}

///
@_NameSource('rule override spec')
class ThirdPartyUser {
  ThirdPartyUser({
    required this.fields,
    required this.protocol,
    required this.userid,
  });

  ThirdPartyUser.fromJson(Map<String, Object?> json)
      : fields = json['fields'] as Map<String, Object?>,
        protocol = json['protocol'] as String,
        userid = json['userid'] as String;
  Map<String, Object?> toJson() => {
        'fields': fields,
        'protocol': protocol,
        'userid': userid,
      };

  /// Information used to identify this third party location.
  Map<String, Object?> fields;

  /// The protocol ID that the third party location is a part of.
  String protocol;

  /// A Matrix User ID represting a third party user.
  String userid;
}

///
@_NameSource('generated')
@EnhancedEnum()
enum EventFormat {
  @EnhancedEnumValue(name: 'client')
  client,
  @EnhancedEnumValue(name: 'federation')
  federation
}

///
@_NameSource('rule override generated')
class StateFilter implements EventFilter, RoomEventFilter {
  StateFilter({
    this.limit,
    this.notSenders,
    this.notTypes,
    this.senders,
    this.types,
    this.containsUrl,
    this.includeRedundantMembers,
    this.lazyLoadMembers,
    this.notRooms,
    this.rooms,
    this.unreadThreadNotifications,
  });

  StateFilter.fromJson(Map<String, Object?> json)
      : limit = ((v) => v != null ? v as int : null)(json['limit']),
        notSenders = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['not_senders']),
        notTypes = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['not_types']),
        senders = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['senders']),
        types = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['types']),
        containsUrl =
            ((v) => v != null ? v as bool : null)(json['contains_url']),
        includeRedundantMembers = ((v) =>
            v != null ? v as bool : null)(json['include_redundant_members']),
        lazyLoadMembers =
            ((v) => v != null ? v as bool : null)(json['lazy_load_members']),
        notRooms = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['not_rooms']),
        rooms = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['rooms']),
        unreadThreadNotifications = ((v) =>
            v != null ? v as bool : null)(json['unread_thread_notifications']);
  @override
  Map<String, Object?> toJson() {
    final limit = this.limit;
    final notSenders = this.notSenders;
    final notTypes = this.notTypes;
    final senders = this.senders;
    final types = this.types;
    final containsUrl = this.containsUrl;
    final includeRedundantMembers = this.includeRedundantMembers;
    final lazyLoadMembers = this.lazyLoadMembers;
    final notRooms = this.notRooms;
    final rooms = this.rooms;
    final unreadThreadNotifications = this.unreadThreadNotifications;
    return {
      if (limit != null) 'limit': limit,
      if (notSenders != null) 'not_senders': notSenders.map((v) => v).toList(),
      if (notTypes != null) 'not_types': notTypes.map((v) => v).toList(),
      if (senders != null) 'senders': senders.map((v) => v).toList(),
      if (types != null) 'types': types.map((v) => v).toList(),
      if (containsUrl != null) 'contains_url': containsUrl,
      if (includeRedundantMembers != null)
        'include_redundant_members': includeRedundantMembers,
      if (lazyLoadMembers != null) 'lazy_load_members': lazyLoadMembers,
      if (notRooms != null) 'not_rooms': notRooms.map((v) => v).toList(),
      if (rooms != null) 'rooms': rooms.map((v) => v).toList(),
      if (unreadThreadNotifications != null)
        'unread_thread_notifications': unreadThreadNotifications,
    };
  }

  /// The maximum number of events to return.
  @override
  int? limit;

  /// A list of sender IDs to exclude. If this list is absent then no senders are excluded. A matching sender will be excluded even if it is listed in the `'senders'` filter.
  @override
  List<String>? notSenders;

  /// A list of event types to exclude. If this list is absent then no event types are excluded. A matching type will be excluded even if it is listed in the `'types'` filter. A '*' can be used as a wildcard to match any sequence of characters.
  @override
  List<String>? notTypes;

  /// A list of senders IDs to include. If this list is absent then all senders are included.
  @override
  List<String>? senders;

  /// A list of event types to include. If this list is absent then all event types are included. A `'*'` can be used as a wildcard to match any sequence of characters.
  @override
  List<String>? types;

  /// If `true`, includes only events with a `url` key in their content. If `false`, excludes those events. If omitted, `url` key is not considered for filtering.
  @override
  bool? containsUrl;

  /// If `true`, sends all membership events for all events, even if they have already
  /// been sent to the client. Does not
  /// apply unless `lazy_load_members` is `true`. See
  /// [Lazy-loading room members](https://spec.matrix.org/unstable/client-server-api/#lazy-loading-room-members)
  /// for more information. Defaults to `false`.
  @override
  bool? includeRedundantMembers;

  /// If `true`, enables lazy-loading of membership events. See
  /// [Lazy-loading room members](https://spec.matrix.org/unstable/client-server-api/#lazy-loading-room-members)
  /// for more information. Defaults to `false`.
  @override
  bool? lazyLoadMembers;

  /// A list of room IDs to exclude. If this list is absent then no rooms are excluded. A matching room will be excluded even if it is listed in the `'rooms'` filter.
  @override
  List<String>? notRooms;

  /// A list of room IDs to include. If this list is absent then all rooms are included.
  @override
  List<String>? rooms;

  /// If `true`, enables per-[thread](https://spec.matrix.org/unstable/client-server-api/#threading) notification
  /// counts. Only applies to the `/sync` endpoint. Defaults to `false`.
  @override
  bool? unreadThreadNotifications;
}

///
@_NameSource('spec')
class RoomFilter {
  RoomFilter({
    this.accountData,
    this.ephemeral,
    this.includeLeave,
    this.notRooms,
    this.rooms,
    this.state,
    this.timeline,
  });

  RoomFilter.fromJson(Map<String, Object?> json)
      : accountData = ((v) => v != null
            ? StateFilter.fromJson(v as Map<String, Object?>)
            : null)(json['account_data']),
        ephemeral = ((v) => v != null
            ? StateFilter.fromJson(v as Map<String, Object?>)
            : null)(json['ephemeral']),
        includeLeave =
            ((v) => v != null ? v as bool : null)(json['include_leave']),
        notRooms = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['not_rooms']),
        rooms = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['rooms']),
        state = ((v) => v != null
            ? StateFilter.fromJson(v as Map<String, Object?>)
            : null)(json['state']),
        timeline = ((v) => v != null
            ? StateFilter.fromJson(v as Map<String, Object?>)
            : null)(json['timeline']);
  Map<String, Object?> toJson() {
    final accountData = this.accountData;
    final ephemeral = this.ephemeral;
    final includeLeave = this.includeLeave;
    final notRooms = this.notRooms;
    final rooms = this.rooms;
    final state = this.state;
    final timeline = this.timeline;
    return {
      if (accountData != null) 'account_data': accountData.toJson(),
      if (ephemeral != null) 'ephemeral': ephemeral.toJson(),
      if (includeLeave != null) 'include_leave': includeLeave,
      if (notRooms != null) 'not_rooms': notRooms.map((v) => v).toList(),
      if (rooms != null) 'rooms': rooms.map((v) => v).toList(),
      if (state != null) 'state': state.toJson(),
      if (timeline != null) 'timeline': timeline.toJson(),
    };
  }

  /// The per user account data to include for rooms.
  StateFilter? accountData;

  /// The ephemeral events to include for rooms. These are the events that appear in the `ephemeral` property in the `/sync` response.
  StateFilter? ephemeral;

  /// Include rooms that the user has left in the sync, default false
  bool? includeLeave;

  /// A list of room IDs to exclude. If this list is absent then no rooms are excluded. A matching room will be excluded even if it is listed in the `'rooms'` filter. This filter is applied before the filters in `ephemeral`, `state`, `timeline` or `account_data`
  List<String>? notRooms;

  /// A list of room IDs to include. If this list is absent then all rooms are included. This filter is applied before the filters in `ephemeral`, `state`, `timeline` or `account_data`
  List<String>? rooms;

  /// The state events to include for rooms.
  StateFilter? state;

  /// The message and state update events to include for rooms.
  StateFilter? timeline;
}

///
@_NameSource('spec')
class Filter {
  Filter({
    this.accountData,
    this.eventFields,
    this.eventFormat,
    this.presence,
    this.room,
  });

  Filter.fromJson(Map<String, Object?> json)
      : accountData = ((v) => v != null
            ? EventFilter.fromJson(v as Map<String, Object?>)
            : null)(json['account_data']),
        eventFields = ((v) => v != null
            ? (v as List).map((v) => v as String).toList()
            : null)(json['event_fields']),
        eventFormat = ((v) => v != null
            ? EventFormat.values.fromString(v as String)!
            : null)(json['event_format']),
        presence = ((v) => v != null
            ? EventFilter.fromJson(v as Map<String, Object?>)
            : null)(json['presence']),
        room = ((v) => v != null
            ? RoomFilter.fromJson(v as Map<String, Object?>)
            : null)(json['room']);
  Map<String, Object?> toJson() {
    final accountData = this.accountData;
    final eventFields = this.eventFields;
    final eventFormat = this.eventFormat;
    final presence = this.presence;
    final room = this.room;
    return {
      if (accountData != null) 'account_data': accountData.toJson(),
      if (eventFields != null)
        'event_fields': eventFields.map((v) => v).toList(),
      if (eventFormat != null) 'event_format': eventFormat.name,
      if (presence != null) 'presence': presence.toJson(),
      if (room != null) 'room': room.toJson(),
    };
  }

  /// The user account data that isn't associated with rooms to include.
  EventFilter? accountData;

  /// List of event fields to include. If this list is absent then all fields are included. The entries may include '.' characters to indicate sub-fields. So ['content.body'] will include the 'body' field of the 'content' object. A literal '.' character in a field name may be escaped using a '\\'. A server may include more fields than were requested.
  List<String>? eventFields;

  /// The format to use for events. 'client' will return the events in a format suitable for clients. 'federation' will return the raw event as received over federation. The default is 'client'.
  EventFormat? eventFormat;

  /// The presence updates to include.
  EventFilter? presence;

  /// Filters to be applied to room data.
  RoomFilter? room;
}

///
@_NameSource('spec')
class OpenIdCredentials {
  OpenIdCredentials({
    required this.accessToken,
    required this.expiresIn,
    required this.matrixServerName,
    required this.tokenType,
  });

  OpenIdCredentials.fromJson(Map<String, Object?> json)
      : accessToken = json['access_token'] as String,
        expiresIn = json['expires_in'] as int,
        matrixServerName = json['matrix_server_name'] as String,
        tokenType = json['token_type'] as String;
  Map<String, Object?> toJson() => {
        'access_token': accessToken,
        'expires_in': expiresIn,
        'matrix_server_name': matrixServerName,
        'token_type': tokenType,
      };

  /// An access token the consumer may use to verify the identity of
  /// the person who generated the token. This is given to the federation
  /// API `GET /openid/userinfo` to verify the user's identity.
  String accessToken;

  /// The number of seconds before this token expires and a new one must
  /// be generated.
  int expiresIn;

  /// The homeserver domain the consumer should use when attempting to
  /// verify the user's identity.
  String matrixServerName;

  /// The string `Bearer`.
  String tokenType;
}

///
@_NameSource('spec')
class Tag {
  Tag({
    this.order,
    this.additionalProperties = const {},
  });

  Tag.fromJson(Map<String, Object?> json)
      : order =
            ((v) => v != null ? (v as num).toDouble() : null)(json['order']),
        additionalProperties = Map.fromEntries(json.entries
            .where((e) => !['order'].contains(e.key))
            .map((e) => MapEntry(e.key, e.value)));
  Map<String, Object?> toJson() {
    final order = this.order;
    return {
      ...additionalProperties,
      if (order != null) 'order': order,
    };
  }

  /// A number in a range `[0,1]` describing a relative
  /// position of the room under the given tag.
  double? order;

  Map<String, Object?> additionalProperties;
}

///
@_NameSource('rule override spec')
class Profile {
  Profile({
    this.avatarUrl,
    this.displayName,
    required this.userId,
  });

  Profile.fromJson(Map<String, Object?> json)
      : avatarUrl = ((v) =>
            v != null ? Uri.parse(v as String) : null)(json['avatar_url']),
        displayName =
            ((v) => v != null ? v as String : null)(json['display_name']),
        userId = json['user_id'] as String;
  Map<String, Object?> toJson() {
    final avatarUrl = this.avatarUrl;
    final displayName = this.displayName;
    return {
      if (avatarUrl != null) 'avatar_url': avatarUrl.toString(),
      if (displayName != null) 'display_name': displayName,
      'user_id': userId,
    };
  }

  /// The avatar url, as an MXC, if one exists.
  Uri? avatarUrl;

  /// The display name of the user, if one exists.
  String? displayName;

  /// The user's matrix user ID.
  String userId;
}

///
@_NameSource('generated')
class SearchUserDirectoryResponse {
  SearchUserDirectoryResponse({
    required this.limited,
    required this.results,
  });

  SearchUserDirectoryResponse.fromJson(Map<String, Object?> json)
      : limited = json['limited'] as bool,
        results = (json['results'] as List)
            .map((v) => Profile.fromJson(v as Map<String, Object?>))
            .toList();
  Map<String, Object?> toJson() => {
        'limited': limited,
        'results': results.map((v) => v.toJson()).toList(),
      };

  /// Indicates if the result list has been truncated by the limit.
  bool limited;

  /// Ordered by rank and then whether or not profile info is available.
  List<Profile> results;
}

///
@_NameSource('rule override generated')
class TurnServerCredentials {
  TurnServerCredentials({
    required this.password,
    required this.ttl,
    required this.uris,
    required this.username,
  });

  TurnServerCredentials.fromJson(Map<String, Object?> json)
      : password = json['password'] as String,
        ttl = json['ttl'] as int,
        uris = (json['uris'] as List).map((v) => v as String).toList(),
        username = json['username'] as String;
  Map<String, Object?> toJson() => {
        'password': password,
        'ttl': ttl,
        'uris': uris.map((v) => v).toList(),
        'username': username,
      };

  /// The password to use.
  String password;

  /// The time-to-live in seconds
  int ttl;

  /// A list of TURN URIs
  List<String> uris;

  /// The username to use.
  String username;
}

///
@_NameSource('generated')
class GetVersionsResponse {
  GetVersionsResponse({
    this.unstableFeatures,
    required this.versions,
  });

  GetVersionsResponse.fromJson(Map<String, Object?> json)
      : unstableFeatures = ((v) => v != null
            ? (v as Map<String, Object?>).map((k, v) => MapEntry(k, v as bool))
            : null)(json['unstable_features']),
        versions = (json['versions'] as List).map((v) => v as String).toList();
  Map<String, Object?> toJson() {
    final unstableFeatures = this.unstableFeatures;
    return {
      if (unstableFeatures != null)
        'unstable_features': unstableFeatures.map((k, v) => MapEntry(k, v)),
      'versions': versions.map((v) => v).toList(),
    };
  }

  /// Experimental features the server supports. Features not listed here,
  /// or the lack of this property all together, indicate that a feature is
  /// not supported.
  Map<String, bool>? unstableFeatures;

  /// The supported versions.
  List<String> versions;
}

///
@_NameSource('rule override generated')
class ServerConfig {
  ServerConfig({
    this.mUploadSize,
  });

  ServerConfig.fromJson(Map<String, Object?> json)
      : mUploadSize =
            ((v) => v != null ? v as int : null)(json['m.upload.size']);
  Map<String, Object?> toJson() {
    final mUploadSize = this.mUploadSize;
    return {
      if (mUploadSize != null) 'm.upload.size': mUploadSize,
    };
  }

  /// The maximum size an upload can be in bytes.
  /// Clients SHOULD use this as a guide when uploading content.
  /// If not listed or null, the size limit should be treated as unknown.
  int? mUploadSize;
}

///
@_NameSource('generated')
class GetUrlPreviewResponse {
  GetUrlPreviewResponse({
    this.matrixImageSize,
    this.ogImage,
  });

  GetUrlPreviewResponse.fromJson(Map<String, Object?> json)
      : matrixImageSize =
            ((v) => v != null ? v as int : null)(json['matrix:image:size']),
        ogImage = ((v) =>
            v != null ? Uri.parse(v as String) : null)(json['og:image']);
  Map<String, Object?> toJson() {
    final matrixImageSize = this.matrixImageSize;
    final ogImage = this.ogImage;
    return {
      if (matrixImageSize != null) 'matrix:image:size': matrixImageSize,
      if (ogImage != null) 'og:image': ogImage.toString(),
    };
  }

  /// The byte-size of the image. Omitted if there is no image attached.
  int? matrixImageSize;

  /// An [MXC URI](https://spec.matrix.org/unstable/client-server-api/#matrix-content-mxc-uris) to the image. Omitted if there is no image.
  Uri? ogImage;
}

///
@_NameSource('generated')
@EnhancedEnum()
enum Method {
  @EnhancedEnumValue(name: 'crop')
  crop,
  @EnhancedEnumValue(name: 'scale')
  scale
}
