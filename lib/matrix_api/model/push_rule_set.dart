/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

enum PushRuleKind { content, override, room, sender, underride }
enum PushRuleAction { notify, dont_notify, coalesce, set_tweak }

class PushRuleSet {
  List<PushRule> content;
  List<PushRule> override;
  List<PushRule> room;
  List<PushRule> sender;
  List<PushRule> underride;

  PushRuleSet.fromJson(Map<String, dynamic> json) {
    if (json['content'] != null) {
      content =
          (json['content'] as List).map((i) => PushRule.fromJson(i)).toList();
    }
    if (json['override'] != null) {
      override =
          (json['override'] as List).map((i) => PushRule.fromJson(i)).toList();
    }
    if (json['room'] != null) {
      room = (json['room'] as List).map((i) => PushRule.fromJson(i)).toList();
    }
    if (json['sender'] != null) {
      sender =
          (json['sender'] as List).map((i) => PushRule.fromJson(i)).toList();
    }
    if (json['underride'] != null) {
      underride =
          (json['underride'] as List).map((i) => PushRule.fromJson(i)).toList();
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (content != null) {
      data['content'] = content.map((v) => v.toJson()).toList();
    }
    if (override != null) {
      data['override'] = override.map((v) => v.toJson()).toList();
    }
    if (room != null) {
      data['room'] = room.map((v) => v.toJson()).toList();
    }
    if (sender != null) {
      data['sender'] = sender.map((v) => v.toJson()).toList();
    }
    if (underride != null) {
      data['underride'] = underride.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class PushRule {
  List<dynamic> actions;
  List<PushConditions> conditions;
  bool isDefault;
  bool enabled;
  String pattern;
  String ruleId;

  PushRule.fromJson(Map<String, dynamic> json) {
    actions = json['actions'];
    isDefault = json['default'];
    enabled = json['enabled'];
    pattern = json['pattern'];
    ruleId = json['rule_id'];
    conditions = json['conditions'] != null
        ? (json['conditions'] as List)
            .map((i) => PushConditions.fromJson(i))
            .toList()
        : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['actions'] = actions;
    data['default'] = isDefault;
    data['enabled'] = enabled;
    if (pattern != null) {
      data['pattern'] = pattern;
    }
    if (conditions != null) {
      data['conditions'] = conditions.map((i) => i.toJson()).toList();
    }
    data['rule_id'] = ruleId;
    return data;
  }
}

class PushConditions {
  String key;
  String kind;
  String pattern;
  String isOperator;

  PushConditions(
    this.kind, {
    this.key,
    this.pattern,
    this.isOperator,
  });

  PushConditions.fromJson(Map<String, dynamic> json) {
    key = json['key'];
    kind = json['kind'];
    pattern = json['pattern'];
    isOperator = json['is'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (key != null) {
      data['key'] = key;
    }
    data['kind'] = kind;
    if (pattern != null) {
      data['pattern'] = pattern;
    }
    if (isOperator != null) {
      data['is'] = isOperator;
    }
    return data;
  }
}
