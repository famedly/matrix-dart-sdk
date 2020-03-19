/// Credentials for the client to use when initiating calls.
class TurnServerCredentials {
  /// The username to use.
  final String username;

  /// The password to use.
  final String password;

  /// A list of TURN URIs
  final List<String> uris;

  /// The time-to-live in seconds
  final double ttl;

  const TurnServerCredentials(
      this.username, this.password, this.uris, this.ttl);

  TurnServerCredentials.fromJson(Map<String, dynamic> json)
      : username = json['username'],
        password = json['password'],
        uris = json['uris'].cast<String>(),
        ttl = json['ttl'];
}
