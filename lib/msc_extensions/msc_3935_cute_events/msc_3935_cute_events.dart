abstract class CuteEventContent {
  static const String eventType = 'im.fluffychat.cute_event';

  const CuteEventContent._();

  static Map<String, dynamic> get googlyEyes => {
        'msgtype': CuteEventContent.eventType,
        'cute_type': 'googly_eyes',
        'body': '👀',
      };
  static Map<String, dynamic> get cuddle => {
        'msgtype': CuteEventContent.eventType,
        'cute_type': 'cuddle',
        'body': '😊',
      };
  static Map<String, dynamic> get hug => {
        'msgtype': CuteEventContent.eventType,
        'cute_type': 'hug',
        'body': '🤗',
      };
}
