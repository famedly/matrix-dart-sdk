import 'package:matrix/matrix.dart';

class RoomSubscription {
  /// The maximum number of timeline events to return per response. The server may cap this number.
  final int timelineLimit;

  /// Required state for each room returned.
  final RequiredStateRequest requiredState;

  const RoomSubscription({
    required this.timelineLimit,
    required this.requiredState,
  });

  Map<String, Object?> toJson() => {
        'timeline_limit': timelineLimit,
        'required_state': requiredState.toJson(),
      };
}
