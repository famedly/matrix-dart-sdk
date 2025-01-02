/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020, 2021 Famedly GmbH
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

// Helper for fast evaluation of push conditions on a bunch of events

import 'package:matrix/matrix.dart';

class EvaluatedPushRuleAction {
  // if this message should be highlighted.
  bool highlight = false;

  // if this is set, play a sound on a notification. Usually the sound is "default".
  String? sound;

  // If this event should notify.
  bool notify = false;

  EvaluatedPushRuleAction();

  EvaluatedPushRuleAction.fromActions(List<dynamic> actions) {
    for (final action in actions) {
      if (action == 'notify') {
        notify = true;
      } else if (action == 'dont_notify') {
        notify = false;
      } else if (action is Map<String, dynamic>) {
        if (action['set_tweak'] == 'highlight') {
          highlight = action.tryGet<bool>('value') ?? true;
        } else if (action['set_tweak'] == 'sound') {
          sound = action.tryGet<String>('value') ?? 'default';
        }
      }
    }
  }
}

class _PatternCondition {
  RegExp pattern = RegExp('');

  // what field to match on, i.e. content.body
  String field = '';

  _PatternCondition.fromEventMatch(PushCondition condition) {
    if (condition.kind != 'event_match') {
      throw 'Logic error: invalid push rule passed to constructor ${condition.kind}';
    }

    final tempField = condition.key;
    if (tempField == null) {
      {
        throw 'No field to match pattern on!';
      }
    }
    field = tempField;

    var tempPat = condition.pattern;
    if (tempPat == null) {
      {
        throw 'PushCondition is missing pattern';
      }
    }
    tempPat =
        RegExp.escape(tempPat).replaceAll('\\*', '.*').replaceAll('\\?', '.');

    if (field == 'content.body') {
      pattern = RegExp('(^|\\W)$tempPat(\$|\\W)', caseSensitive: false);
    } else {
      pattern = RegExp('^$tempPat\$', caseSensitive: false);
    }
  }

  bool match(Map<String, String> content) {
    final fieldContent = content[field];
    if (fieldContent == null) {
      return false;
    }
    return pattern.hasMatch(fieldContent);
  }
}

enum _CountComparisonOp {
  eq,
  lt,
  le,
  ge,
  gt,
}

class _MemberCountCondition {
  _CountComparisonOp op = _CountComparisonOp.eq;
  int count = 0;

  _MemberCountCondition.fromEventMatch(PushCondition condition) {
    if (condition.kind != 'room_member_count') {
      throw 'Logic error: invalid push rule passed to constructor ${condition.kind}';
    }

    var is_ = condition.is$;

    if (is_ == null) {
      throw 'Member condition has no condition set: $is_';
    }

    if (is_.startsWith('==')) {
      is_ = is_.replaceFirst('==', '');
      op = _CountComparisonOp.eq;
      count = int.parse(is_);
    } else if (is_.startsWith('>=')) {
      is_ = is_.replaceFirst('>=', '');
      op = _CountComparisonOp.ge;
      count = int.parse(is_);
    } else if (is_.startsWith('<=')) {
      is_ = is_.replaceFirst('<=', '');
      op = _CountComparisonOp.le;
      count = int.parse(is_);
    } else if (is_.startsWith('>')) {
      is_ = is_.replaceFirst('>', '');
      op = _CountComparisonOp.gt;
      count = int.parse(is_);
    } else if (is_.startsWith('<')) {
      is_ = is_.replaceFirst('<', '');
      op = _CountComparisonOp.lt;
      count = int.parse(is_);
    } else {
      op = _CountComparisonOp.eq;
      count = int.parse(is_);
    }
  }

  bool match(int memberCount) {
    switch (op) {
      case _CountComparisonOp.ge:
        return memberCount >= count;
      case _CountComparisonOp.gt:
        return memberCount > count;
      case _CountComparisonOp.le:
        return memberCount <= count;
      case _CountComparisonOp.lt:
        return memberCount < count;
      case _CountComparisonOp.eq:
        return memberCount == count;
    }
  }
}

class _OptimizedRules {
  List<_PatternCondition> patterns = [];
  List<_MemberCountCondition> memberCounts = [];
  List<String> notificationPermissions = [];
  bool matchDisplayname = false;
  EvaluatedPushRuleAction actions = EvaluatedPushRuleAction();

  _OptimizedRules.fromRule(PushRule rule) {
    if (!rule.enabled) return;

    for (final condition in rule.conditions ?? []) {
      switch (condition.kind) {
        case 'event_match':
          patterns.add(_PatternCondition.fromEventMatch(condition));
          break;
        case 'contains_display_name':
          matchDisplayname = true;
          break;
        case 'room_member_count':
          memberCounts.add(_MemberCountCondition.fromEventMatch(condition));
          break;
        case 'sender_notification_permission':
          final key = condition.key;
          if (key != null) {
            notificationPermissions.add(key);
          }
          break;
        default:
          throw Exception('Unknown push condition: ${condition.kind}');
      }
    }
    actions = EvaluatedPushRuleAction.fromActions(rule.actions);
  }

  EvaluatedPushRuleAction? match(
    Map<String, String> event,
    String? displayName,
    int memberCount,
    Room room,
  ) {
    if (patterns.any((pat) => !pat.match(event))) {
      return null;
    }
    if (memberCounts.any((pat) => !pat.match(memberCount))) {
      return null;
    }
    if (matchDisplayname) {
      final body = event.tryGet<String>('content.body');
      if (displayName == null || body == null) {
        return null;
      }

      final regex = RegExp(
        '(^|\\W)${RegExp.escape(displayName)}(\$|\\W)',
        caseSensitive: false,
      );
      if (!regex.hasMatch(body)) {
        return null;
      }
    }

    if (notificationPermissions.isNotEmpty) {
      final sender = event.tryGet<String>('sender');
      if (sender == null ||
          notificationPermissions.any(
            (notificationType) => !room.canSendNotification(
              sender,
              notificationType: notificationType,
            ),
          )) {
        return null;
      }
    }

    return actions;
  }
}

class PushruleEvaluator {
  final List<_OptimizedRules> _override = [];
  final Map<String, EvaluatedPushRuleAction> _room_rules = {};
  final Map<String, EvaluatedPushRuleAction> _sender_rules = {};
  final List<_OptimizedRules> _content_rules = [];
  final List<_OptimizedRules> _underride = [];

  PushruleEvaluator.fromRuleset(PushRuleSet ruleset) {
    for (final o in ruleset.override ?? []) {
      if (!o.enabled) continue;
      try {
        _override.add(_OptimizedRules.fromRule(o));
      } catch (e) {
        Logs().d('Error parsing push rule $o', e);
      }
    }
    for (final u in ruleset.underride ?? []) {
      if (!u.enabled) continue;
      try {
        _underride.add(_OptimizedRules.fromRule(u));
      } catch (e) {
        Logs().d('Error parsing push rule $u', e);
      }
    }
    for (final c in ruleset.content ?? []) {
      if (!c.enabled) continue;
      final rule = PushRule(
        actions: c.actions,
        conditions: [
          PushCondition(
            kind: 'event_match',
            key: 'content.body',
            pattern: c.pattern,
          ),
        ],
        ruleId: c.ruleId,
        default$: c.default$,
        enabled: c.enabled,
      );
      try {
        _content_rules.add(_OptimizedRules.fromRule(rule));
      } catch (e) {
        Logs().d('Error parsing push rule $rule', e);
      }
    }
    for (final r in ruleset.room ?? []) {
      if (r.enabled) {
        _room_rules[r.ruleId] = EvaluatedPushRuleAction.fromActions(r.actions);
      }
    }
    for (final r in ruleset.sender ?? []) {
      if (r.enabled) {
        _sender_rules[r.ruleId] =
            EvaluatedPushRuleAction.fromActions(r.actions);
      }
    }
  }

  Map<String, String> _flattenJson(
    Map<String, dynamic> obj,
    Map<String, String> flattened,
    String prefix,
  ) {
    for (final entry in obj.entries) {
      final key = prefix == '' ? entry.key : '$prefix.${entry.key}';
      final value = entry.value;
      if (value is String) {
        flattened[key] = value;
      } else if (value is Map<String, dynamic>) {
        flattened = _flattenJson(value, flattened, key);
      }
    }

    return flattened;
  }

  EvaluatedPushRuleAction match(Event event) {
    final memberCount = event.room.getParticipants([Membership.join]).length;
    final displayName = event.room
        .unsafeGetUserFromMemoryOrFallback(event.room.client.userID!)
        .displayName;
    final content = _flattenJson(event.toJson(), {}, '');
    // ensure roomid is present
    content['room_id'] = event.room.id;

    for (final o in _override) {
      final actions = o.match(content, displayName, memberCount, event.room);
      if (actions != null) {
        return actions;
      }
    }

    final roomActions = _room_rules[event.room.id];
    if (roomActions != null) {
      return roomActions;
    }

    final senderActions = _sender_rules[event.senderId];
    if (senderActions != null) {
      return senderActions;
    }

    for (final o in _content_rules) {
      final actions = o.match(content, displayName, memberCount, event.room);
      if (actions != null) {
        return actions;
      }
    }

    for (final o in _underride) {
      final actions = o.match(content, displayName, memberCount, event.room);
      if (actions != null) {
        return actions;
      }
    }

    return EvaluatedPushRuleAction();
  }
}
