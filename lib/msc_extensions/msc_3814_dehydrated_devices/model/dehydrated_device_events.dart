// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';

class DehydratedDeviceEvents {
  String? nextBatch;
  List<ToDeviceEvent>? events;

  DehydratedDeviceEvents({this.nextBatch, this.events});

  DehydratedDeviceEvents.fromJson(Map<String, dynamic> json)
    : nextBatch = json['next_batch'] as String?,
      events = json
          .tryGetList<Map<String, dynamic>>('events')
          ?.map(ToDeviceEvent.fromJson)
          .toList();

  Map<String, dynamic> toJson() {
    return {
      if (nextBatch != null) 'next_batch': nextBatch,
      if (events != null) 'events': events,
    };
  }
}
