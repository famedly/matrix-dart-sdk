// A model which holds the delayed event and it's timer

import 'dart:async';

class DelayedEventCanceller {
  final String delayedEventId;
  final Timer restartTimer;

  DelayedEventCanceller({
    required this.delayedEventId,
    required this.restartTimer,
  });
}
