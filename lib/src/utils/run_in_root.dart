// SPDX-FileCopyrightText: 2019-Present, 2020, 2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:matrix/matrix.dart';

void runInRoot<T>(FutureOr<T> Function() fn) {
  // ignore: discarded_futures
  Zone.root.run(() async {
    try {
      await fn();
    } catch (e, s) {
      Logs().e('Error thrown in root zone', e, s);
    }
  });
}
