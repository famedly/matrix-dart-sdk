# MSC extensions

This folder contains non-spec feature implementations, usually proposed in Matrix Specification Changes (MSCs).

Please try to cover the following conventions:

- name your implementation `/lib/msc_extensions/msc_NUMER_short_name/whatsoever.dart`,
  e.g. `/lib/msc_extensions/msc_3588_stories/stories.dart`
- please link the MSC in a comment in the first line:
  ```dart
  /// MSC3588: Stories As Rooms (https://github.com/matrix-org/matrix-spec-proposals/blob/d818877504cfda00ac52430ba5b9e8423c878b77/proposals/3588-stories-as-rooms.md)
  ```
- the implementation should provide an `extension NAME on ...` (usually `Client`)
- proprietary implementations without MSC should be given a useful name and 
  corresponding, useful documentation comments, e.g. `/lib/msc_extensions/extension_recent_emoji/recent_emoji.dart`
- Moreover, all implemented non-spec features should be listed below:

## Implemented non-spec features

- MSC 1236 - Widget API V2
- `io.element.recent_emoji` - recent emoji sync in account data