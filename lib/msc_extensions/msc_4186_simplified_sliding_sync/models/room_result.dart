import 'package:matrix/matrix.dart';

class RoomResult {
  /// An integer that can be used to sort rooms based on the last "proper" activity in the room. Greater means more recent.
  ///
  /// "Proper" activity is defined as an event being received is one of the following types: m.room.create, m.room.message, m.room.encrypted, m.sticker, m.call.invite, m.poll.start, m.beacon_info.
  ///
  /// For rooms that the user is not currently joined to, this instead represents when the relevant membership happened, e.g. when the user left the room.
  ///
  /// The exact value of bump_stamp is opaque to the client, a server may use e.g. an auto-incrementing integer, a timestamp, etc.
  ///
  /// The bump_stamp may decrease in subsequent responses, if e.g. an event was redacted/removed (or purged in cases of retention policies).
  final int bumpStamp;

  /// The current membership of the user, or omitted if user not in room (for peeking).
  // TODO: migrate to enum
  final String? membership;

  /// The name of the lists that match this room. The field is omitted if it doesn't match any list and is included only due to a subscription.
  final List<String>? lists;

  // Currently or previously joined rooms
// When a user is or has been in the room, the following field are also returned:

  /// Room name or calculated room name.
  final String? name;

  /// Room avatar
// TODO: migrate to Uri
  final String? avatar;

  /// A truncated list of users in the room that can be used to calculate the room name. Will first include joined users, then invited users, and then finally left users. The same as the m.heroes section in the /v3/sync specification
  final List<StrippedHero>? heroes;

  /// Flag to specify whether the room is a direct-message room (according to account data). If absent the room is not a DM room.
  final bool? isDm;

  /// Flag which is set when this is the first time the server is sending this data on this connection, or if the client should replace all room data with what is returned. Clients can use this flag to replace or update their local state. The absence of this flag means false.
  final bool? initial;

  /// Flag which is set if we're returning more historic events due to the timeline limit having increased. See "Changing room configs" section.
  final bool? expandedTimeline;

  /// Changes in the current state of the room.
  ///
  /// To handle state being deleted, the list may include a StateStub type (c.f. schema below) that only has type and state_key fields. The presence or absence of content field can be used to differentiate between the two cases.
  final List<BasicEvent>? requiredState;

  /// The latest events in the room. May not include all events if e.g. there were more events than the configured timeline_limit, c.f. the limited field.
  ///
  /// If limited is true then we include bundle aggregations for the event, as per /v3/sync.
  ///
  /// The last event in the list is the most recent.
  final List<MatrixEvent>? timelineEvents;

  /// A token that can be passed as a start parameter to the /rooms/<room_id>/messages API to retrieve earlier messages.
  final String? prevBatch;

  /// True if there are more events since the previous sync than were included in the timeline_events field, or that the client should paginate to fetch more events.
  ///
  /// Note that server may return fewer than the requested number of events and still set limited to true, e.g. because there is a gap in the history the server has for the room.
  ///
  /// Absence means false
  final bool limited;

  /// The number of timeline events which have "just occurred" and are not historical, i.e. that have happened since the previous sync request. The last N events are 'live' and should be treated as such.
  ///
  /// This is mostly useful to e.g. determine whether a given @mention event should make a noise or not. Clients cannot rely solely on the absence of initial: true to determine live events because if a room not in the sliding window bumps into the window because of an @mention it will have initial: true yet contain a single live event (with potentially other old events in the timeline).
  final int? numLive;

  /// The number of users with membership of join, including the client's own user ID. (same as /v3/sync m.joined_member_count)
  final int? joinedCount;

  /// The number of users with membership of invite. (same as /v3/sync m.invited_member_count)
  final int? invitedCount;

  /// The total number of unread notifications for this room. (same as /v3/sync).
  ///
  /// Does not included threaded notifications, which are returned in an extension.
  final int? notificationCount;

  /// The number of unread notifications for this room with the highlight flag set. (same as /v3/sync)
  ///
  /// Does not included threaded notifications, which are returned in an extension.
  final int? highlightCount;

  // Invite/knock/rejections
// For rooms the user has not been joined to the client also gets the stripped state events. This is commonly the case for invites or knocks, but can also be for when the user has rejected an invite.

  /// Stripped state events (for rooms where the user is invited). Same as rooms.invite.$room_id.invite_state for invites in /v3/sync.
  final StrippedStateEvent? stripped_state;

  const RoomResult({
    required this.bumpStamp,
    this.membership,
    this.lists,
    this.name,
    this.avatar,
    this.heroes,
    this.isDm,
    this.initial,
    this.expandedTimeline,
    this.requiredState,
    this.timelineEvents,
    this.prevBatch,
    this.limited = false,
    this.numLive,
    this.joinedCount,
    this.invitedCount,
    this.notificationCount,
    this.highlightCount,
    this.stripped_state,
  });

  factory RoomResult.fromJson(Map<String, Object?> json) => RoomResult(
        bumpStamp: json['bump_stamp'] as int,
        membership: json['membership'] as String?,
        lists: (json['lists'] as List?)?.cast<String>(),
        name: json['name'] as String?,
        avatar: json['avatar'] as String?,
        heroes: json.containsKey('heroes')
            ? (json['heroes'] as List)
                .map((v) => StrippedHero.fromJson(v))
                .toList()
            : null,
        isDm: json['is_dm'] as bool?,
        initial: json['initial'] as bool?,
        expandedTimeline: json['expanded_timeline'] as bool?,
        requiredState: json.containsKey('required_state')
            ? (json['required_state'] as List)
                .map((v) => BasicEvent.fromJson(v))
                .toList()
            : null,
        timelineEvents: json.containsKey('timeline_events')
            ? (json['timeline_events'] as List)
                .map((v) => MatrixEvent.fromJson(v))
                .toList()
            : null,
        prevBatch: json['prev_batch'] as String?,
        limited: json['limited'] as bool? ?? false,
        numLive: json['num_live'] as int?,
        joinedCount: json['joined_count'] as int?,
        invitedCount: json['invited_count'] as int?,
        notificationCount: json['notification_count'] as int?,
        highlightCount: json['highlight_count'] as int?,
        stripped_state: json.containsKey('stripped_state')
            ? StrippedStateEvent.fromJson(
                (json['stripped_state'] as Map).cast<String, Object?>(),
              )
            : null,
      );
}
