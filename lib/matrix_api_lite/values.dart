// OpenAPI only supports real enums (modeled as enum in generated/model.dart).

// In this file, possible values are defined manually,
// for cases where other values are allowed too.

class PushRuleAction {
  static final notify = 'notify';
  static final dontNotify = 'dont_notify';
  static final coalesce = 'coalesce';
  static final setTweak = 'set_tweak';
}

class TagType {
  static final favourite = 'm.favourite';
  static final lowPriority = 'm.lowpriority';
  static final serverNotice = 'm.server_notice';

  static bool isValid(String tag) =>
      !tag.startsWith('m.') ||
      [favourite, lowPriority, serverNotice].contains(tag);
}
