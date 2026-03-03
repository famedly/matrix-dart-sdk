final class ReactionPayload {
  final String key;
  final bool isEphemeral;
  final String callId;
  final String deviceId;
  final String relType;
  final String eventId;

  ReactionPayload({
    required this.key,
    required this.isEphemeral,
    required this.callId,
    required this.deviceId,
    required this.relType,
    required this.eventId,
  });

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'is_ephemeral': isEphemeral,
      'call_id': callId,
      'device_id': deviceId,
      'm.relates_to': {
        'rel_type': relType,
        'event_id': eventId,
      },
    };
  }

  factory ReactionPayload.fromJson(Map<String, dynamic> map) {
    return ReactionPayload(
      key: map['key'] as String,
      isEphemeral: map['is_ephemeral'] as bool,
      callId: map['call_id'] as String,
      deviceId: map['device_id'] as String,
      relType: map['m.relates_to']['rel_type'] as String,
      eventId: map['m.relates_to']['event_id'] as String,
    );
  }
}
