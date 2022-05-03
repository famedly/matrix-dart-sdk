library extension_recent_emoji;

import 'package:matrix/matrix.dart';

/// Syncs recent emojis in account data
///
/// Keeps recently used emojis stored in account data by
///
/// ```js
/// { // the account data
///   "io.element.recent_emoji": {
///     "recent_emoji" : {
///       "emoji character": n, // number used
///     }
///   }
/// }
/// ```
///
/// Proprietary extension by New Vector Ltd.
extension RecentEmojiExtension on Client {
  /// returns the recently used emojis from the account data
  ///
  /// There's no corresponding standard or MSC, it's just the reverse-engineered
  /// API from New Vector Ltd.
  Map<String, int> get recentEmojis => Map.fromEntries(
        (accountData['io.element.recent_emoji']?.content['recent_emoji']
                    as List<dynamic>? ??
                [])
            .map(
          (e) => MapEntry(e[0] as String, e[1] as int),
        ),
      );

  /// +1 the stated emoji in the account data
  Future<void> addRecentEmoji(String emoji) async {
    final data = recentEmojis;
    if (data.containsKey(emoji)) {
      data[emoji] = data[emoji]! + 1;
    } else {
      data[emoji] = 1;
    }
    return setRecentEmojiData(data);
  }

  /// sets the raw recent emoji account data. Use [addRecentEmoji] instead
  Future<void> setRecentEmojiData(Map<String, int> data) async {
    final content = List.from(data.entries.map((e) => [e.key, e.value]));
    return setAccountData(
        userID!, 'io.element.recent_emoji', {'recent_emoji': content});
  }
}
