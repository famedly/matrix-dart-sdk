/// Defines event status:
/// - removed
/// - error: (http request failed)
/// - sending: (http request started)
/// - sent: (http request successful)
/// - synced: (event came from sync loop)
enum EventStatus {
  error,
  sending,
  sent,
  synced,
}

/// Returns `EventStatusEnum` value from `intValue`.
///
/// - -2 == error;
/// - -1 == sending;
/// -  0 == sent;
/// -  1 == synced;
EventStatus eventStatusFromInt(int intValue) =>
    EventStatus.values[intValue + 2];

/// Takes two [EventStatus] values and returns the one with higher
/// (better in terms of message sending) status.
EventStatus latestEventStatus(EventStatus status1, EventStatus status2) =>
    status1.intValue > status2.intValue ? status1 : status2;

extension EventStatusExtension on EventStatus {
  /// Returns int value of the event status.
  ///
  /// - -2 == error;
  /// - -1 == sending;
  /// -  0 == sent;
  /// -  1 == synced;
  int get intValue => (index - 2);

  /// Return `true` if the `EventStatus` equals `error`.
  bool get isError => this == EventStatus.error;

  /// Return `true` if the `EventStatus` equals `sending`.
  bool get isSending => this == EventStatus.sending;

  /// Returns `true` if the status is sent or later:
  /// [EventStatus.sent] or [EventStatus.synced].
  bool get isSent => [
        EventStatus.sent,
        EventStatus.synced,
      ].contains(this);

  /// Returns `true` if the status is `synced`: [EventStatus.synced]
  bool get isSynced => this == EventStatus.synced;
}
