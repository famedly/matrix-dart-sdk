// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../matrix_api_lite/utils/try_get_map_extension.dart';

extension type PowerLevel(int level) {
  /// 2^53 - 1 from https://spec.matrix.org/v1.15/appendices/#canonical-json
  static const int ownerPowerLevel = 9007199254740991;
  static const int defaultAdminLevel = 100;
  static const int defaultModeratorLevel = 50;
  static const int defaultUserLevel = 0;

  static PowerLevel get owner => PowerLevel(ownerPowerLevel);
  static PowerLevel get admin => PowerLevel(defaultAdminLevel);
  static PowerLevel get moderator => PowerLevel(defaultModeratorLevel);
  static PowerLevel get user => PowerLevel(defaultUserLevel);

  /// Power level of [userId] from `m.room.power_levels` content and the
  /// `m.room.create` event.
  ///
  /// Creators (the create sender plus `additional_creators`) are owners when
  /// the room version is 12 or newer. A missing or unparsable version is not.
  /// Otherwise the level is `users`, then `users_default`, then 100 for the
  /// create sender, else 0.
  static PowerLevel forUser(
    String userId, {
    Map<String, Object?>? powerLevelsContent,
    String? createSender,
    Map<String, Object?>? createContent,
  }) {
    final roomVersion = createContent?.tryGet<String>('room_version');
    final additionalCreators =
        createContent?.tryGetList<String>('additional_creators') ?? const [];
    final creators = {?createSender, ...additionalCreators};
    if (creators.contains(userId) &&
        (int.tryParse(roomVersion ?? '') ?? 0) >= 12) {
      return owner;
    }

    final userSpecificPowerLevel = powerLevelsContent
        ?.tryGetMap<String, Object?>('users')
        ?.tryGet<int>(userId);
    final defaultUserPowerLevel = powerLevelsContent?.tryGet<int>(
      'users_default',
    );
    final fallbackPowerLevel = createSender == userId
        ? defaultAdminLevel
        : defaultUserLevel;
    return PowerLevel(
      userSpecificPowerLevel ?? defaultUserPowerLevel ?? fallbackPowerLevel,
    );
  }

  PowerLevelRole get role => level == ownerPowerLevel
      ? PowerLevelRole.owner
      : level >= defaultAdminLevel
      ? PowerLevelRole.admin
      : level >= defaultModeratorLevel
      ? PowerLevelRole.moderator
      : PowerLevelRole.user;

  bool operator <(PowerLevel other) => level < other.level;
  bool operator >(PowerLevel other) => level > other.level;
  bool operator >=(PowerLevel other) => level >= other.level;
  bool operator <=(PowerLevel other) => level <= other.level;
}

enum PowerLevelRole { user, moderator, admin, owner }
