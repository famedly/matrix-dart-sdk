// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite.dart';

mixin EventType {
  static const String markedUnread = 'm.marked_unread';
  static const String oldMarkedUnread = 'com.famedly.marked_unread';
}

class MarkedUnread {
  final bool unread;

  const MarkedUnread(this.unread);

  MarkedUnread.fromJson(Map<String, dynamic> json)
      : unread = json.tryGet<bool>('unread') ?? false;

  Map<String, dynamic> toJson() => {'unread': unread};
}
