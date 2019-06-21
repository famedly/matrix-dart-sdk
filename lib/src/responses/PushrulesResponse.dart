/*
 * Copyright (c) 2019 Zender & Kurtz GbR.
 *
 * Authors:
 *   Christian Pauly <krille@famedly.com>
 *   Marcel Radzio <mtrnord@famedly.com>
 *
 * This file is part of famedlysdk.
 *
 * famedlysdk is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * famedlysdk is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with famedly.  If not, see <http://www.gnu.org/licenses/>.
 */
import 'package:json_annotation/json_annotation.dart';

part 'PushrulesResponse.g.dart';

@JsonSerializable(explicitToJson: true, nullable: false)
class PushrulesResponse {
  @JsonKey(nullable: false)
  Global global;

  PushrulesResponse(
    this.global,
  );

  factory PushrulesResponse.fromJson(Map<String, dynamic> json) =>
      _$PushrulesResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PushrulesResponseToJson(this);
}

@JsonSerializable(explicitToJson: true)
class Global {
  List<PushRule> content;
  List<PushRule> room;
  List<PushRule> sender;
  List<PushRule> override;
  List<PushRule> underride;

  Global(
    this.content,
    this.room,
    this.sender,
    this.override,
    this.underride,
  );

  factory Global.fromJson(Map<String, dynamic> json) => _$GlobalFromJson(json);

  Map<String, dynamic> toJson() => _$GlobalToJson(this);
}

@JsonSerializable(explicitToJson: true)
class PushRule {
  @JsonKey(nullable: false)
  List<dynamic> actions;
  List<Condition> conditions;
  @JsonKey(nullable: false, name: "default")
  bool contentDefault;
  @JsonKey(nullable: false)
  bool enabled;
  @JsonKey(nullable: false)
  String ruleId;
  String pattern;

  PushRule(
    this.actions,
    this.conditions,
    this.contentDefault,
    this.enabled,
    this.ruleId,
    this.pattern,
  );

  factory PushRule.fromJson(Map<String, dynamic> json) =>
      _$PushRuleFromJson(json);

  Map<String, dynamic> toJson() => _$PushRuleToJson(this);
}

@JsonSerializable(explicitToJson: true)
class Condition {
  String key;
  @JsonKey(name: "is")
  String conditionIs;
  @JsonKey(nullable: false)
  String kind;
  String pattern;

  Condition(
    this.key,
    this.conditionIs,
    this.kind,
    this.pattern,
  );

  factory Condition.fromJson(Map<String, dynamic> json) =>
      _$ConditionFromJson(json);

  Map<String, dynamic> toJson() => _$ConditionToJson(this);
}
