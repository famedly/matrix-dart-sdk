import 'package:matrix/matrix.dart';

class SyncRequestResponse {
  /// The next position token in the sliding window to request.
  final String pos;

  /// A map of list key to list results.
  final Map<String, SyncListResult>? lists;

  /// A map of room ID to room results.
  final Map<String, RoomResult> rooms;

  /// A map of extension key to extension results. Different extensions have different result formats.
  final Map<String, Map<String, Object?>>? extensions;

  const SyncRequestResponse({
    required this.pos,
    required this.lists,
    required this.rooms,
    required this.extensions,
  });

  factory SyncRequestResponse.fromJson(Map<String, Object?> json) =>
      SyncRequestResponse(
        pos: json['pos'] as String,
        lists: json.containsKey('lists')
            ? (json['lists'] as Map).map(
                (k, v) => MapEntry(
                  k,
                  SyncListResult.fromJson(v),
                ),
              )
            : null,
        rooms: (json['rooms'] as Map).map(
          (k, v) => MapEntry(
            k,
            RoomResult.fromJson(v),
          ),
        ),
        extensions: json.containsKey('extensions')
            ? json['extensions'] as Map<String, Map<String, Object?>>
            : null,
      );
}
