/// The global ruleset.
class PushRules {
  final GlobalPushRules global;

  PushRules.fromJson(Map<String, dynamic> json)
      : this.global = GlobalPushRules.fromJson(json["global"]);
}

/// The global ruleset.
class GlobalPushRules {
  final List<PushRule> content;
  final List<PushRule> override;
  final List<PushRule> room;
  final List<PushRule> sender;
  final List<PushRule> underride;

  GlobalPushRules.fromJson(Map<String, dynamic> json)
      : this.content = json.containsKey("content")
            ? PushRule.fromJsonList(json["content"])
            : null,
        this.override = json.containsKey("override")
            ? PushRule.fromJsonList(json["content"])
            : null,
        this.room = json.containsKey("room")
            ? PushRule.fromJsonList(json["room"])
            : null,
        this.sender = json.containsKey("sender")
            ? PushRule.fromJsonList(json["sender"])
            : null,
        this.underride = json.containsKey("underride")
            ? PushRule.fromJsonList(json["underride"])
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
    List<PushRule> objList = [];
    list.forEach((json) {
      objList.add(PushRule.fromJson(json));
    });
    return objList;
  }

  PushRule.fromJson(Map<String, dynamic> json)
      : this.actions = json["actions"],
        this.isDefault = json["default"],
        this.enabled = json["enabled"],
        this.ruleId = json["rule_id"],
        this.conditions = json.containsKey("conditions")
            ? PushRuleConditions.fromJsonList(json["conditions"])
            : null,
        this.pattern = json["pattern"];
}

/// Conditions when this pushrule should be active.
class PushRuleConditions {
  final String kind;
  final String key;
  final String pattern;
  final String is_;

  static List<PushRuleConditions> fromJsonList(List<dynamic> list) {
    List<PushRuleConditions> objList = [];
    list.forEach((json) {
      objList.add(PushRuleConditions.fromJson(json));
    });
    return objList;
  }

  PushRuleConditions.fromJson(Map<String, dynamic> json)
      : this.kind = json["kind"],
        this.key = json["key"],
        this.pattern = json["pattern"],
        this.is_ = json["is"];
}
