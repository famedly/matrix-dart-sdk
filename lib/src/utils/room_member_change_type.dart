import 'package:matrix/matrix.dart';

/// The kind of what has changed with this m.room.member event to have a
/// comparable type.
enum RoomMemberChangeType {
  /// The user has changed the avatar.
  avatar,

  /// The user has changed the displayname.
  displayname,

  /// The user has joined the chat from being not a user before. The user
  /// also was not invited before.
  join,

  /// The user was invited before and has joined.
  acceptInvite,

  /// The user was invited before and has left.
  rejectInvite,

  /// The user was invited before and the invitation got withdrawn by someone.
  withdrawInvitation,

  /// The user was joined before and has now left the room by themself.
  leave,

  /// The user was joined before and has now been kicked out of the room by
  /// someone.
  kick,

  /// The user has been invited by someone.
  invite,

  /// The user has been banned by someone.
  ban,

  /// The user was banned before and has been unbanned by someone.
  unban,

  /// The user was not a member of the room and now knocks.
  knock,

  /// Something else which is not handled yet.
  other,
}

extension RoomMemberChangeTypeExtension on Event {
  /// Returns the comparable type of this m.room.member event to handle this
  /// differently in the UI. If the event is not of the type m.room.member,
  /// this throws an exception!
  RoomMemberChangeType get roomMemberChangeType {
    if (type != EventTypes.RoomMember) {
      throw Exception(
        'Tried to call `roomMemberChangeType` but the Event has a type of `$type`',
      );
    }

    // Has the membership changed?
    final newMembership = content.tryGet<String>('membership') ?? '';
    final oldMembership = prevContent?.tryGet<String>('membership') ?? '';

    if (newMembership != oldMembership) {
      if (oldMembership == 'invite' && newMembership == 'join') {
        return RoomMemberChangeType.acceptInvite;
      } else if (oldMembership == 'invite' && newMembership == 'leave') {
        if (stateKey == senderId) {
          return RoomMemberChangeType.rejectInvite;
        } else {
          return RoomMemberChangeType.withdrawInvitation;
        }
      } else if ((oldMembership == 'leave' || oldMembership == '') &&
          newMembership == 'join') {
        return RoomMemberChangeType.join;
      } else if (oldMembership == 'join' && newMembership == 'ban') {
        return RoomMemberChangeType.ban;
      } else if (oldMembership == 'join' &&
          newMembership == 'leave' &&
          stateKey != senderId) {
        return RoomMemberChangeType.kick;
      } else if (oldMembership == 'join' &&
          newMembership == 'leave' &&
          stateKey == senderId) {
        return RoomMemberChangeType.leave;
      } else if (oldMembership != newMembership && newMembership == 'ban') {
        return RoomMemberChangeType.ban;
      } else if (oldMembership == 'ban' && newMembership == 'leave') {
        return RoomMemberChangeType.unban;
      } else if (newMembership == 'invite') {
        return RoomMemberChangeType.invite;
      } else if (newMembership == 'knock') {
        return RoomMemberChangeType.knock;
      }
    } else if (newMembership == 'join') {
      final newAvatar = content.tryGet<String>('avatar_url') ?? '';
      final oldAvatar = prevContent?.tryGet<String>('avatar_url') ?? '';

      final newDisplayname = content.tryGet<String>('displayname') ?? '';
      final oldDisplayname = prevContent?.tryGet<String>('displayname') ?? '';

      // Has the user avatar changed?
      if (newAvatar != oldAvatar) {
        return RoomMemberChangeType.avatar;
      }
      // Has the user displayname changed?
      else if (newDisplayname != oldDisplayname && stateKey != null) {
        return RoomMemberChangeType.displayname;
      }
    }
    return RoomMemberChangeType.other;
  }
}
