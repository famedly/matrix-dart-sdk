class Participant {
  final String userId;
  final String deviceId;

  Participant({required this.userId, required this.deviceId});

  String get id => '$userId:$deviceId';

  @override
  String toString() {
    return id;
  }

  @override
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Participant &&
          userId == other.userId &&
          deviceId == other.deviceId;

  @override
  int get hashCode => userId.hashCode ^ deviceId.hashCode;

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
        userId: json['userId'] as String,
        deviceId: json['deviceId'] as String,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'deviceId': deviceId,
      };
}
