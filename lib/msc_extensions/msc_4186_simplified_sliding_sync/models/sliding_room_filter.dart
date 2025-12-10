import 'package:matrix/matrix.dart';

class SlidingRoomFilter {
  /// Flag which only returns rooms present (or not) in the m.direct entry in account data.
  ///
  /// If unset, both DM rooms and non-DM rooms are returned. If False, only non-DM rooms are returned. If True, only DM rooms are returned.
  final bool? isDm;

  /// Filter the room based on the space they belong to according to m.space.child state events.
  ///
  /// If multiple spaces are present, a room can be part of any one of the listed spaces (OR'd). The server will inspect the m.space.child state events for the JOINED space room IDs given. Servers MUST NOT navigate subspaces. It is up to the client to give a complete list of spaces to navigate. Only rooms directly mentioned as m.space.child events in these spaces will be returned. Unknown spaces or spaces the user is not joined to will be ignored.
  final List<String>? spaces;

  /// Flag which only returns rooms which have an m.room.encryption state event.
  ///
  /// If unset, both encrypted and unencrypted rooms are returned. If false, only unencrypted rooms are returned. If True, only encrypted rooms are returned.
  final bool? isEncrypted;

  /// Flag which only returns rooms the user is currently invited to.
  ///
  /// If unset, both invited and joined rooms are returned. If false, no invited rooms are returned. If true, only invited rooms are returned.
  final bool? isInvited;

  /// If specified, only rooms where the m.room.create event has a type matching one of the strings in this array will be returned.
  ///
  /// If this field is unset, all rooms are returned regardless of type. This can be used to get the initial set of spaces for an account. For rooms which do not have a room type, use null to include them.
  final List<Maybe<String>>? roomTypes;

  /// Same as [roomTypes] but inverted.
  ///
  /// This can be used to filter out spaces from the room list. If a type is in both room_types and not_room_types, then not_room_types wins and they are not included in the result.
  final List<Maybe<String>>? notRoomTypes;

  /// Filter the room based on its [room tags](https://spec.matrix.org/v1.16/client-server-api/#room-tagging).
  ///
  /// If multiple tags are present, a room can have any one of the listed tags (OR'd).
  final List<String>? tags;

  /// Filter the room based on its [room tags](https://spec.matrix.org/v1.16/client-server-api/#room-tagging).
  ///
  /// If multiple tags are present, a room can have any one of the listed tags (OR'd).
  final List<String>? notTags;

  const SlidingRoomFilter({
    required this.isDm,
    required this.spaces,
    required this.isEncrypted,
    required this.isInvited,
    required this.roomTypes,
    required this.notRoomTypes,
    required this.tags,
    required this.notTags,
  });

  Map<String, Object?> toJson() => {
        if (isDm != null) 'is_dm': isDm,
        if (spaces != null) 'spaces': spaces,
        if (isEncrypted != null) 'is_encrypted': isEncrypted,
        if (isInvited != null) 'is_invited': isInvited,
        if (roomTypes is Some) 'room_types': roomTypes,
        if (notRoomTypes is Some) 'not_room_types': notRoomTypes,
        if (tags != null) 'tags': tags,
        if (notTags != null) 'not_tags': notTags,
      };
}
