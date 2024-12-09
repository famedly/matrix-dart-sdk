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

import 'package:matrix/matrix.dart';

/// Represents a Matrix User which may be a participant in a Matrix Room.
class User extends StrippedStateEvent {
  final Room room;
  final Map<String, Object?>? prevContent;

  factory User(
    String id, {
    String? membership,
    String? displayName,
    String? avatarUrl,
    required Room room,
  }) {
    return User.fromState(
      stateKey: id,
      senderId: id,
      content: {
        if (membership != null) 'membership': membership,
        if (displayName != null) 'displayname': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      },
      typeKey: EventTypes.RoomMember,
      room: room,
    );
  }

  User.fromState({
    required String super.stateKey,
    super.content = const {},
    required String typeKey,
    required super.senderId,
    required this.room,
    this.prevContent,
  }) : super(
          type: typeKey,
        );

  /// The full qualified Matrix ID in the format @username:server.abc.
  String get id => stateKey ?? '@unknown:unknown';

  /// The displayname of the user if the user has set one.
  String? get displayName =>
      content.tryGet<String>('displayname') ??
      (membership == Membership.join
          ? null
          : prevContent?.tryGet<String>('displayname'));

  /// Returns the power level of this user.
  int get powerLevel => room.getPowerLevelByUserId(id);

  /// The membership status of the user. One of:
  /// join
  /// invite
  /// leave
  /// ban
  Membership get membership => Membership.values.firstWhere(
        (e) {
          if (content['membership'] != null) {
            return e.toString() == 'Membership.${content['membership']}';
          }
          return false;
        },
        orElse: () => Membership.join,
      );

  /// The avatar if the user has one.
  Uri? get avatarUrl {
    final uri = content.tryGet<String>('avatar_url') ??
        (membership == Membership.join
            ? null
            : prevContent?.tryGet<String>('avatar_url'));
    return uri == null ? null : Uri.tryParse(uri);
  }

  /// Returns the displayname or the local part of the Matrix ID if the user
  /// has no displayname. If [formatLocalpart] is true, then the localpart will
  /// be formatted in the way, that all "_" characters are becomming white spaces and
  /// the first character of each word becomes uppercase.
  /// If [mxidLocalPartFallback] is true, then the local part of the mxid will be shown
  /// if there is no other displayname available. If not then this will return "Unknown user".
  String calcDisplayname({
    bool? formatLocalpart,
    bool? mxidLocalPartFallback,
    MatrixLocalizations i18n = const MatrixDefaultLocalizations(),
  }) {
    formatLocalpart ??= room.client.formatLocalpart;
    mxidLocalPartFallback ??= room.client.mxidLocalPartFallback;
    final displayName = this.displayName;
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    final stateKey = this.stateKey;
    if (stateKey != null && mxidLocalPartFallback) {
      if (!formatLocalpart) {
        return stateKey.localpart ?? '';
      }
      final words = stateKey.localpart?.replaceAll('_', ' ').split(' ') ?? [];
      for (var i = 0; i < words.length; i++) {
        if (words[i].isNotEmpty) {
          words[i] = words[i][0].toUpperCase() + words[i].substring(1);
        }
      }
      return words.join(' ').trim();
    }
    return i18n.unknownUser;
  }

  /// Call the Matrix API to kick this user from this room.
  Future<void> kick() async => await room.kick(id);

  /// Call the Matrix API to ban this user from this room.
  Future<void> ban() async => await room.ban(id);

  /// Call the Matrix API to unban this banned user from this room.
  Future<void> unban() async => await room.unban(id);

  /// Call the Matrix API to change the power level of this user.
  Future<void> setPower(int power) async => await room.setPower(id, power);

  /// Returns an existing direct chat ID with this user or creates a new one.
  /// Returns null on error.
  Future<String> startDirectChat({
    bool? enableEncryption,
    List<StateEvent>? initialState,
    bool waitForSync = true,
  }) async =>
      room.client.startDirectChat(
        id,
        enableEncryption: enableEncryption,
        initialState: initialState,
        waitForSync: waitForSync,
      );

  /// The newest presence of this user if there is any and null if not.
  @Deprecated('Deprecated in favour of currentPresence.')
  Presence? get presence => room.client.presences[id]?.toPresence();

  @Deprecated('Use fetchCurrentPresence() instead')
  Future<CachedPresence> get currentPresence => fetchCurrentPresence();

  /// The newest presence of this user if there is any. Fetches it from the
  /// database first and then from the server if necessary or returns offline.
  Future<CachedPresence> fetchCurrentPresence() =>
      room.client.fetchCurrentPresence(id);

  /// Whether the client is able to ban/unban this user.
  bool get canBan => room.canBan && powerLevel < room.ownPowerLevel;

  /// Whether the client is able to kick this user.
  bool get canKick =>
      [Membership.join, Membership.invite].contains(membership) &&
      room.canKick &&
      powerLevel < room.ownPowerLevel;

  @Deprecated('Use [canChangeUserPowerLevel] instead.')
  bool get canChangePowerLevel => canChangeUserPowerLevel;

  /// Whether the client is allowed to change the power level of this user.
  /// Please be aware that you can only set the power level to at least your own!
  bool get canChangeUserPowerLevel =>
      room.canChangePowerLevel &&
      (powerLevel < room.ownPowerLevel || id == room.client.userID);

  @override
  bool operator ==(Object other) => (other is User &&
      other.id == id &&
      other.room == room &&
      other.membership == membership);

  @override
  int get hashCode => Object.hash(id, room, membership);

  /// Get the mention text to use in a plain text body to mention this specific user
  /// in this specific room
  String get mention {
    // if the displayname has [ or ] or : we can't build our more fancy stuff, so fall back to the id
    // [] is used for the delimitors
    // If we allowed : we could get collissions with the mxid fallbacks
    final displayName = this.displayName;
    if (displayName == null ||
        displayName.isEmpty ||
        {'[', ']', ':'}.any(displayName.contains)) {
      return id;
    }

    final identifier =
        '@${RegExp(r'^\w+$').hasMatch(displayName) ? displayName : '[$displayName]'}';

    // get all the users with the same display name
    final allUsersWithSameDisplayname = room.getParticipants();
    allUsersWithSameDisplayname.removeWhere(
      (user) =>
          user.id == id ||
          (user.displayName?.isEmpty ?? true) ||
          user.displayName != displayName,
    );
    if (allUsersWithSameDisplayname.isEmpty) {
      return identifier;
    }
    // ok, we have multiple users with the same display name....time to calculate a hash
    final hashes = allUsersWithSameDisplayname.map((u) => _hash(u.id));
    final ourHash = _hash(id);
    // hash collission...just return our own mxid again
    if (hashes.contains(ourHash)) {
      return id;
    }
    return '$identifier#$ourHash';
  }

  /// Get the mention fragments for this user.
  Set<String> get mentionFragments {
    final displayName = this.displayName;
    if (displayName == null ||
        displayName.isEmpty ||
        {'[', ']', ':'}.any(displayName.contains)) {
      return {};
    }
    final identifier =
        '@${RegExp(r'^\w+$').hasMatch(displayName) ? displayName : '[$displayName]'}';

    final hash = _hash(id);
    return {identifier, '$identifier#$hash'};
  }
}

const _maximumHashLength = 10000;
String _hash(String s) =>
    (s.codeUnits.fold<int>(0, (a, b) => a + b) % _maximumHashLength).toString();

extension FromStrippedStateEventExtension on StrippedStateEvent {
  User asUser(Room room) => User.fromState(
        // state key should always be set for member events
        stateKey: stateKey!,
        content: content,
        typeKey: type,
        senderId: senderId,
        room: room,
      );
}
