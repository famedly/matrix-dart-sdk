class CloudflareRemoteTrack {
  final String sessionId;
  final String trackName;
  final String mid;

  CloudflareRemoteTrack({
    required this.sessionId,
    required this.trackName,
    required this.mid,
  });

  factory CloudflareRemoteTrack.fromJson(Map<String, Object?> json) =>
      CloudflareRemoteTrack(
        sessionId: json['sessionId'] as String,
        trackName: json['trackName'] as String,
        mid: json['mid'] as String,
      );

  Map<String, Object?> toJson() {
    return {
      'sessionId': sessionId,
      'trackName': trackName,
      'mid': mid,
    };
  }

  @override
  String toString() {
    return '$sessionId:$trackName:$mid';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CloudflareRemoteTrack &&
          sessionId == other.sessionId &&
          trackName == other.trackName &&
          mid == other.mid;

  @override
  int get hashCode => sessionId.hashCode ^ trackName.hashCode ^ mid.hashCode;
}
