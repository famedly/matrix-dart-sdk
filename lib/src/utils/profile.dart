/// Represents a user profile returned by a /profile request.
class Profile {
  /// The user's avatar URL if they have set one, otherwise null.
  final Uri avatarUrl;

  /// The user's display name if they have set one, otherwise null.
  final String displayname;

  /// This API may return keys which are not limited to displayname or avatar_url.
  final Map<String, dynamic> content;

  Profile.fromJson(Map<String, dynamic> json)
      : avatarUrl = Uri.parse(json['avatar_url']),
        displayname = json['displayname'],
        content = json;

  @override
  bool operator ==(dynamic other) =>
      avatarUrl == other.avatarUrl && displayname == other.displayname;
}
