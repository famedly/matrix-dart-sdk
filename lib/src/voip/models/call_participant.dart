class CallParticipant {
  final String userId;
  final String? deviceId;

  CallParticipant({
    required this.userId,
    this.deviceId,
  });

  String get id {
    String pid = userId;
    if (deviceId != null) {
      pid += ':$deviceId';
    }
    return pid;
  }

  @override
  String toString() {
    return id;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallParticipant &&
          userId == other.userId &&
          deviceId == other.deviceId;

  @override
  int get hashCode => userId.hashCode ^ deviceId.hashCode;

  // factory CallParticipant.fromId(String id) {
  //   final int lastIndex = id.lastIndexOf(':');
  //   final userId = id.substring(0, lastIndex);
  //   final deviceId = id.substring(lastIndex + 1);
  //   if (!userId.isValidMatrixId) {
  //     throw FormatException(
  //         '[CallParticipant] $userId is not a valid matrixId');
  //   }
  //   return CallParticipant(
  //     userId: userId,
  //     deviceId: deviceId,
  //   );
  // }

  // factory CallParticipant.fromJson(Map<String, dynamic> json) =>
  //     CallParticipant(
  //       userId: json['userId'] as String,
  //       deviceId: json['deviceId'] as String,
  //     );

  // Map<String, dynamic> toJson() => {
  //       'userId': userId,
  //       'deviceId': deviceId,
  //     };
}
