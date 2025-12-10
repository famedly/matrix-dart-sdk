import 'package:matrix/matrix.dart';

class SyncListConfig {
  /// The maximum number of timeline events to return per response. The server may cap this number.
  final int timeline_limit;

  /// Required state for each room returned.
  final RequiredStateRequest required_state;

  /// Sliding window range. If this field is missing, no sliding window is used and all rooms are returned in this list. Integers are inclusive, and are 0-indexed. (This is a 2-tuple.)
  final (int, int)? range;

  /// Filters to apply to the list.
  final SlidingRoomFilter? filters;

  const SyncListConfig({
    required this.timeline_limit,
    required this.required_state,
    required this.range,
    required this.filters,
  });

  Map<String, Object?> toJson() => {
        'timeline_limit': timeline_limit,
        'required_state': required_state.toJson(),
        if (range != null) 'range': [range!.$1, range!.$2],
        if (filters != null) 'filters': filters!.toJson(),
      };
}
