// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';

extension TryGetPushRule on PushRuleSet {
  static PushRuleSet tryFromJson(Map<String, dynamic> json) {
    try {
      return PushRuleSet.fromJson(json);
    } catch (e, s) {
      Logs().v('Malformed PushRuleSet', e, s);
    }
    return PushRuleSet.fromJson({});
  }
}
