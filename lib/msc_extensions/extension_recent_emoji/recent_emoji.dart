/// Extension to synchronize the recently used widgets with Element clients
library;

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
  Map<String, int> get recentEmojis {
    final recents = <String, int>{};

    accountData['io.element.recent_emoji']
        ?.content
        .tryGetList('recent_emoji')
        ?.forEach((item) {
      if (item is List) {
        if (item.length > 1 && item[0] is String && item[1] is int) {
          recents[item[0]] = item[1];
        }
      }
    });

    return recents;
  }

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
    if (userID == null) return;
    final content = List.from(data.entries.map((e) => [e.key, e.value]));
    return setAccountData(
        userID!, 'io.element.recent_emoji', {'recent_emoji': content});
  }
}
