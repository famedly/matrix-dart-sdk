class PushRule {
  final String ruleId;
  final bool isDefault;
  final bool enabled;
  final List<Conditions> conditions;
  final List<dynamic> actions;

  PushRule(
      {this.ruleId,
      this.isDefault,
      this.enabled,
      this.conditions,
      this.actions});

  PushRule.fromJson(Map<String, dynamic> json)
      : ruleId = json['rule_id'],
        isDefault = json['is_default'],
        enabled = json['enabled'],
        conditions = _getConditionsFromJson(json['conditions']),
        actions = json['actions'];

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['rule_id'] = this.ruleId;
    data['is_default'] = this.isDefault;
    data['enabled'] = this.enabled;
    if (this.conditions != null) {
      data['conditions'] = this.conditions.map((v) => v.toJson()).toList();
    }
    data['actions'] = this.actions;
    return data;
  }

  static List<Conditions> _getConditionsFromJson(List<dynamic> json) {
    List<Conditions> conditions = [];
    if (json == null) return conditions;
    for (int i = 0; i < json.length; i++) {
      conditions.add(Conditions.fromJson(json[i]));
    }
    return conditions;
  }
}

class Conditions {
  String key;
  String kind;
  String pattern;

  Conditions({this.key, this.kind, this.pattern});

  Conditions.fromJson(Map<String, dynamic> json) {
    key = json['key'];
    kind = json['kind'];
    pattern = json['pattern'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['key'] = this.key;
    data['kind'] = this.kind;
    data['pattern'] = this.pattern;
    return data;
  }
}
