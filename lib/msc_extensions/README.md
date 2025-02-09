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
- MSC 2835 - UIA login
- MSC 3814 - Dehydrated Devices
- MSC 3861 - Next-generation auth for Matrix, based on OAuth 2.0/OIDC
  - MSC 1597 - Better spec for matrix identifiers
  - MSC 2964 - Usage of OAuth 2.0 authorization code grant and refresh token grant
  - MSC 2966 - Usage of OAuth 2.0 Dynamic Client Registration in Matrix
  - MSC 2967 - API scopes
  - MSC 3824 - OIDC aware clients
  - MSC 4191 - Account management deep-linking
- MSC 3935 - Cute Events
- `io.element.recent_emoji` - recent emoji sync in account data
