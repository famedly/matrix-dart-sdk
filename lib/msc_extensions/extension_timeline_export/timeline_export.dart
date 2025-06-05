import 'dart:convert';

import 'package:matrix/matrix_api_lite.dart';
import 'package:matrix/src/event.dart';
import 'package:matrix/src/timeline.dart';

extension TimelineExportExtension on Timeline {
  /// Exports timeline events from a Matrix room within a specified date range.
  ///
  /// The export process provides progress updates through the returned stream with the following information:
  /// - Total number of events exported
  /// - Count of unable-to-decrypt (UTD) events
  /// - Count of media events (images, audio, video, files)
  /// - Number of unique users involved
  ///
  /// ```dart
  /// // Example usage:
  /// final timeline = room.timeline;
  /// final oneWeekAgo = DateTime.now().subtract(Duration(days: 7));
  ///
  /// // Export last week's messages, excluding encrypted events
  /// await for (final result in timeline.export(
  ///   from: oneWeekAgo,
  ///   filter: (event) => event?.type != EventTypes.Encrypted,
  /// )) {
  ///   if (result is ExportProgress) {
  ///     print('Progress: ${result.totalEvents} events exported');
  ///   } else if (result is ExportComplete) {
  ///     print('Export completed with ${result.events.length} events');
  ///   } else if (result is ExportError) {
  ///     print('Export failed: ${result.error}');
  ///   }
  /// }
  /// ```
  ///
  /// [from] Optional start date to filter events. If null, exports from the beginning.
  /// [until] Optional end date to filter events. If null, exports up to the latest event.
  /// [filter] Optional function to filter events. Return true to include the event.
  /// [requestHistoryCount] Optional. The number of events to request from the server at once.
  ///
  /// Returns a [Stream] of [ExportResult] which can be:
  /// - [ExportProgress]: Provides progress updates during export
  /// - [ExportComplete]: Contains the final list of exported events
  /// - [ExportError]: Contains error information if export fails
  Stream<ExportResult> export({
    DateTime? from,
    DateTime? until,
    bool Function(Event)? filter,
    int requestHistoryCount = 500,
  }) async* {
    final eventsToExport = <Event>[];
    var utdEventsCount = 0;
    var mediaEventsCount = 0;
    final users = <String>{};

    try {
      yield ExportProgress(
        source: ExportSource.timeline,
        totalEvents: 0,
        utdEvents: 0,
        mediaEvents: 0,
        users: 0,
      );

      void exportEvent(Event event) {
        eventsToExport.add(event);

        if (event.type == EventTypes.Encrypted &&
            event.messageType == MessageTypes.BadEncrypted) {
          utdEventsCount++;
        } else if (event.type == EventTypes.Message &&
            {
              MessageTypes.Sticker,
              MessageTypes.Image,
              MessageTypes.Audio,
              MessageTypes.Video,
              MessageTypes.File,
            }.contains(event.messageType)) {
          mediaEventsCount++;
        }
        users.add(event.senderId);
      }

      // From the timeline
      if (until == null || events.last.originServerTs.isBefore(until)) {
        for (final event in events) {
          if (from != null && event.originServerTs.isBefore(from)) break;
          if (until != null && event.originServerTs.isAfter(until)) continue;
          if (filter != null && !filter(event)) continue;
          exportEvent(event);
        }
      }
      yield ExportProgress(
        source: ExportSource.timeline,
        totalEvents: eventsToExport.length,
        utdEvents: utdEventsCount,
        mediaEvents: mediaEventsCount,
        users: users.length,
      );

      if (from != null && events.last.originServerTs.isBefore(from)) {
        yield ExportComplete(
          events: eventsToExport,
          totalEvents: eventsToExport.length,
          utdEvents: utdEventsCount,
          mediaEvents: mediaEventsCount,
          users: users.length,
        );
        return;
      }

      // From the database
      final eventsFromStore = await room.client.database
              ?.getEventList(room, start: events.length) ??
          [];
      if (eventsFromStore.isNotEmpty) {
        if (until == null ||
            eventsFromStore.last.originServerTs.isBefore(until)) {
          for (final event in eventsFromStore) {
            if (from != null && event.originServerTs.isBefore(from)) break;
            if (until != null && event.originServerTs.isAfter(until)) continue;
            if (filter != null && !filter(event)) continue;
            exportEvent(event);
          }
        }
        yield ExportProgress(
          source: ExportSource.database,
          totalEvents: eventsToExport.length,
          utdEvents: utdEventsCount,
          mediaEvents: mediaEventsCount,
          users: users.length,
        );

        if (from != null &&
            eventsFromStore.last.originServerTs.isBefore(from)) {
          yield ExportComplete(
            events: eventsToExport,
            totalEvents: eventsToExport.length,
            utdEvents: utdEventsCount,
            mediaEvents: mediaEventsCount,
            users: users.length,
          );
          return;
        }
      }

      // From the server
      var prevBatch = room.prev_batch;
      final encryption = room.client.encryption;
      do {
        if (prevBatch == null) break;
        try {
          final resp = await room.client.getRoomEvents(
            room.id,
            Direction.b,
            from: prevBatch,
            limit: requestHistoryCount,
            filter: jsonEncode(StateFilter(lazyLoadMembers: true).toJson()),
          );
          if (resp.chunk.isEmpty) break;

          for (final matrixEvent in resp.chunk) {
            var event = Event.fromMatrixEvent(matrixEvent, room);
            if (event.type == EventTypes.Encrypted && encryption != null) {
              event = await encryption.decryptRoomEvent(event);
              if (event.type == EventTypes.Encrypted &&
                  event.messageType == MessageTypes.BadEncrypted &&
                  event.content['can_request_session'] == true) {
                // Await requestKey() here to ensure decrypted message bodies
                await event.requestKey().catchError((_) {});
              }
            }
            if (from != null && event.originServerTs.isBefore(from)) break;
            if (until != null && event.originServerTs.isAfter(until)) continue;
            if (filter != null && !filter(event)) continue;
            exportEvent(event);
          }
          yield ExportProgress(
            source: ExportSource.server,
            totalEvents: eventsToExport.length,
            utdEvents: utdEventsCount,
            mediaEvents: mediaEventsCount,
            users: users.length,
          );

          prevBatch = resp.end;
          if (resp.chunk.length < requestHistoryCount) break;

          if (from != null && resp.chunk.last.originServerTs.isBefore(from)) {
            break;
          }
        } on MatrixException catch (e) {
          // We have no permission anymore to request the history, so we stop here
          // and return the events we have so far
          if (e.error == MatrixError.M_FORBIDDEN) {
            break;
          }
          // If it's not a forbidden error, we yield an [ExportError]
          rethrow;
        }
      } while (true);

      yield ExportComplete(
        events: eventsToExport,
        totalEvents: eventsToExport.length,
        utdEvents: utdEventsCount,
        mediaEvents: mediaEventsCount,
        users: users.length,
      );
    } catch (e) {
      yield ExportError(
        error: e.toString(),
        totalEvents: eventsToExport.length,
        utdEvents: utdEventsCount,
        mediaEvents: mediaEventsCount,
        users: users.length,
      );
    }
  }
}

/// Base class for export results
sealed class ExportResult {
  /// Total events count
  final int totalEvents;

  /// Unable-to-decrypt events count
  final int utdEvents;

  /// Media events count
  final int mediaEvents;

  /// Users count
  final int users;

  ExportResult({
    required this.totalEvents,
    required this.utdEvents,
    required this.mediaEvents,
    required this.users,
  });
}

enum ExportSource {
  timeline,
  database,
  server,
}

/// Represents progress during export
final class ExportProgress extends ExportResult {
  /// Export source
  final ExportSource source;

  ExportProgress({
    required this.source,
    required super.totalEvents,
    required super.utdEvents,
    required super.mediaEvents,
    required super.users,
  });
}

/// Represents successful completion with exported events
final class ExportComplete extends ExportResult {
  final List<Event> events;
  ExportComplete({
    required this.events,
    required super.totalEvents,
    required super.utdEvents,
    required super.mediaEvents,
    required super.users,
  });
}

/// Represents an error during export
final class ExportError extends ExportResult {
  final String error;
  ExportError({
    required this.error,
    required super.totalEvents,
    required super.utdEvents,
    required super.mediaEvents,
    required super.users,
  });
}
