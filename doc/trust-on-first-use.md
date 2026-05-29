<!--
SPDX-FileCopyrightText: 2019-Present Famedly GmbH

SPDX-License-Identifier: AGPL-3.0-or-later
-->

To avoid man-in-the-middle attacks without the hassle to force users to verify
all keys before sending a message, **Trust On First Use (TOFU)** is a common
compromise.

The concept is simple: When using Cross-Signing, inform the user about
master key changes **before** they sends an event into the encrypted room.
You can store that a user confirmed to this by this:

```dart
// Assuming that this user has cross signing enabled and we know the master key:
final masterKey = client.userDeviceKeys['@userid:domain.abc']?.masterKey;
masterKey?.trustOnFirstUse();
```

You can check the datetime when you have done this like this:

```dart
final tofuSince = masterKey?.trustOnFirstUseSince; // returns a DateTime?
```

You can loop over all users in a room like this:

```dart
Future<List<User>> getUntrustedUsers(Room room) async {
    if (!room.encrypted) return [];

    final users = await room.requestParticipants();

    return users.where((user) {
        if (user.id == room.client.userID) return false;
        final keys = room.client.userDeviceKeys[user.id];
        final masterKey = keys?.masterKey;

        if (keys == null ||
            masterKey == null ||
            masterKey.verified ||
            masterKey.trustOnFirstUseSince != null) {
            return false;
        }
        return true;
    }).toList();
}
```

Then display those users to the user and set trustOnFirstUse flag at their master key.
This should be done before every message sending into the room.