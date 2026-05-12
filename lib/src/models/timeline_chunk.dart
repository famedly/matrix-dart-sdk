// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';

class TimelineChunk {
  String prevBatch; // pos of the first event of the database timeline chunk
  String nextBatch;

  List<Event> events;
  TimelineChunk({
    required this.events,
    this.prevBatch = '',
    this.nextBatch = '',
  });
}
