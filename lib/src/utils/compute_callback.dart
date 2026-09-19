// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

typedef ComputeCallback = Future<R> Function<Q, R>(
  FutureOr<R> Function(Q message) callback,
  Q message, {
  String? debugLabel,
});

// keep types in sync with [computeCallbackFromRunInBackground]
// ignore: unused-code
typedef ComputeRunner = Future<T> Function<T, U>(
  FutureOr<T> Function(U arg) function,
  U arg,
);
