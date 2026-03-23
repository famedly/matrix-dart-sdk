// OpenAPI only supports real enums (modeled as enum in generated/model.dart).

// In this file, possible values are defined manually,
// for cases where other values are allowed too.

class PushRuleAction {
  static const notify = 'notify';
  static const dontNotify = 'dont_notify';
  static const coalesce = 'coalesce';
  static const setTweak = 'set_tweak';
}

class TagType {
  static const favourite = 'm.favourite';
  static const lowPriority = 'm.lowpriority';
  static const serverNotice = 'm.server_notice';

  static bool isValid(String tag) =>
      !tag.startsWith('m.') ||
      [favourite, lowPriority, serverNotice].contains(tag);
}
