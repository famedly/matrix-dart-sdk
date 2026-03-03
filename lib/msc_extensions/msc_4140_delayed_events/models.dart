class ScheduledDelayedEventsResponse {
  final List<ScheduledDelayedEvent> scheduledEvents;
  final String? nextBatch;

  ScheduledDelayedEventsResponse({
    required this.scheduledEvents,
    this.nextBatch,
  });

  factory ScheduledDelayedEventsResponse.fromJson(Map<String, dynamic> json) {
    final list = json['delayed_events'] ?? json['scheduled'] as List;
    final scheduledEvents =
        list.map((e) => ScheduledDelayedEvent.fromJson(e)).toList();

    return ScheduledDelayedEventsResponse(
      scheduledEvents: List<ScheduledDelayedEvent>.from(scheduledEvents),
      nextBatch: json['next_batch'] as String?,
    );
  }
}

class ScheduledDelayedEvent {
  final String delayId;
  final String roomId;
  final String type;
  final String? stateKey;
  final int delay;
  final int runningSince;
  final Map<String, Object?> content;

  ScheduledDelayedEvent({
    required this.delayId,
    required this.roomId,
    required this.type,
    this.stateKey,
    required this.delay,
    required this.runningSince,
    required this.content,
  });

  factory ScheduledDelayedEvent.fromJson(Map<String, dynamic> json) {
    return ScheduledDelayedEvent(
      delayId: json['delay_id'] as String,
      roomId: json['room_id'] as String,
      type: json['type'] as String,
      stateKey: json['state_key'] as String?,
      delay: json['delay'] as int,
      runningSince: json['running_since'] as int,
      content: json['content'] as Map<String, Object?>,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'delay_id': delayId,
      'room_id': roomId,
      'type': type,
      'state_key': stateKey,
      'delay': delay,
      'running_since': runningSince,
      'content': content,
    };
  }
}
