// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'PushrulesResponse.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PushrulesResponse _$PushrulesResponseFromJson(Map<String, dynamic> json) {
  return PushrulesResponse(
      Global.fromJson(json['global'] as Map<String, dynamic>));
}

Map<String, dynamic> _$PushrulesResponseToJson(PushrulesResponse instance) =>
    <String, dynamic>{'global': instance.global.toJson()};

Global _$GlobalFromJson(Map<String, dynamic> json) {
  return Global(
      (json['content'] as List)
          ?.map((e) =>
              e == null ? null : PushRule.fromJson(e as Map<String, dynamic>))
          ?.toList(),
      (json['room'] as List)
          ?.map((e) =>
              e == null ? null : PushRule.fromJson(e as Map<String, dynamic>))
          ?.toList(),
      (json['sender'] as List)
          ?.map((e) =>
              e == null ? null : PushRule.fromJson(e as Map<String, dynamic>))
          ?.toList(),
      (json['override'] as List)
          ?.map((e) =>
              e == null ? null : PushRule.fromJson(e as Map<String, dynamic>))
          ?.toList(),
      (json['underride'] as List)
          ?.map((e) =>
              e == null ? null : PushRule.fromJson(e as Map<String, dynamic>))
          ?.toList());
}

Map<String, dynamic> _$GlobalToJson(Global instance) => <String, dynamic>{
      'content': instance.content?.map((e) => e?.toJson())?.toList(),
      'room': instance.room?.map((e) => e?.toJson())?.toList(),
      'sender': instance.sender?.map((e) => e?.toJson())?.toList(),
      'override': instance.override?.map((e) => e?.toJson())?.toList(),
      'underride': instance.underride?.map((e) => e?.toJson())?.toList()
    };

PushRule _$PushRuleFromJson(Map<String, dynamic> json) {
  return PushRule(
      json['actions'] as List,
      (json['conditions'] as List)
          ?.map((e) =>
              e == null ? null : Condition.fromJson(e as Map<String, dynamic>))
          ?.toList(),
      json['default'] as bool,
      json['enabled'] as bool,
      json['ruleId'] as String,
      json['pattern'] as String);
}

Map<String, dynamic> _$PushRuleToJson(PushRule instance) => <String, dynamic>{
      'actions': instance.actions,
      'conditions': instance.conditions?.map((e) => e?.toJson())?.toList(),
      'default': instance.contentDefault,
      'enabled': instance.enabled,
      'ruleId': instance.ruleId,
      'pattern': instance.pattern
    };

Condition _$ConditionFromJson(Map<String, dynamic> json) {
  return Condition(json['key'] as String, json['is'] as String,
      json['kind'] as String, json['pattern'] as String);
}

Map<String, dynamic> _$ConditionToJson(Condition instance) => <String, dynamic>{
      'key': instance.key,
      'is': instance.conditionIs,
      'kind': instance.kind,
      'pattern': instance.pattern
    };
