/// The global ruleset.
class PushRules {
  final GlobalPushRules global;

  PushRules.fromJson(Map<String, dynamic> json)
      : global = GlobalPushRules.fromJson(json['global']);
}

/// The global ruleset.
class GlobalPushRules {
  final List<PushRule> content;
  final List<PushRule> override;
  final List<PushRule> room;
  final List<PushRule> sender;
  final List<PushRule> underride;

  GlobalPushRules.fromJson(Map<String, dynamic> json)
      : content = json.containsKey('content')
            ? PushRule.fromJsonList(json['content'])
            : null,
        override = json.containsKey('override')
            ? PushRule.fromJsonList(json['content'])
            : null,
        room = json.containsKey('room')
            ? PushRule.fromJsonList(json['room'])
            : null,
        sender = json.containsKey('sender')
            ? PushRule.fromJsonList(json['sender'])
            : null,
        underride = json.containsKey('underride')
            ? PushRule.fromJsonList(json['underride'])
            : null;
}

/// A single pushrule.
class PushRule {
  final List actions;
  final bool isDefault;
  final bool enabled;
  final String ruleId;
  final List<PushRuleConditions> conditions;
  final String pattern;

  static List<PushRule> fromJsonList(List<dynamic> list) {
    var objList = <PushRule>[];
    list.forEach((json) {
      objList.add(PushRule.fromJson(json));
    });
    return objList;
  }

  PushRule.fromJson(Map<String, dynamic> json)
      : actions = json['actions'],
        isDefault = json['default'],
        enabled = json['enabled'],
        ruleId = json['rule_id'],
        conditions = json.containsKey('conditions')
            ? PushRuleConditions.fromJsonList(json['conditions'])
            : null,
        pattern = json['pattern'];
}

/// Conditions when this pushrule should be active.
class PushRuleConditions {
  final String kind;
  final String key;
  final String pattern;
  final String is_;

  static List<PushRuleConditions> fromJsonList(List<dynamic> list) {
    var objList = <PushRuleConditions>[];
    list.forEach((json) {
      objList.add(PushRuleConditions.fromJson(json));
    });
    return objList;
  }

  PushRuleConditions.fromJson(Map<String, dynamic> json)
      : kind = json['kind'],
        key = json['key'],
        pattern = json['pattern'],
        is_ = json['is'];
}
