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
