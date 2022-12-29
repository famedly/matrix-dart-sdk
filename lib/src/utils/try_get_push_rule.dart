import 'package:matrix/matrix.dart';

extension TryGetPushRule on PushRuleSet {
  static PushRuleSet tryFromJson(Map<String, Object?> json) {
    try {
      return PushRuleSet.fromJson(json);
    } catch (e, s) {
      Logs().v('Malformed PushRuleSet', e, s);
    }

    return PushRuleSet.fromJson({});
  }
}
