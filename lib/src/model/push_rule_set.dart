/* MIT License
* 
* Copyright (C) 2019, 2020, 2021 Famedly GmbH
* 
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
* 
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
* 
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
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
