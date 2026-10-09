// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

// JavaScriptCore entrypoint for push rule evaluation in the iOS Notification
// Service Extension. Logic and JSON contract: PushruleEvaluator.evaluateJson.

import 'dart:js_interop';

import 'matrix.dart';

// NOTE: Don't export this from the library. It's not part of the public API.

@JS('matrixEvaluatePushRules')
external set _evaluate(JSFunction f);

void main() {
  // A bare JSContext has no console; logging there throws, so keep logs
  // effectively off.
  Logs().level = Level.wtf;
  _evaluate = ((JSString input) => PushruleEvaluator.evaluateJson(
    input.toDart,
  ).toJS).toJS;
}
