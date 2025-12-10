class StrippedHero {
  /// The user ID of the hero.
  final String user_id;

  /// The display name of the user from the membership event, if set
  final String? displayName;

  /// The avatar url from the membership event, if set
  // TODO: migrate to Uri
  final String? avatarUrl;

  const StrippedHero({required this.user_id, this.displayName, this.avatarUrl});

  factory StrippedHero.fromJson(Map<String, Object?> json) => StrippedHero(
        user_id: json['user_id'] as String,
        displayName: json['displayname'] as String?,
        avatarUrl: json['avatar_url'] as String?,
      );
}
