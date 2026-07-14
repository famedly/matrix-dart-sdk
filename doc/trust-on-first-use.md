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
// Assuming that this user has cross signing enabled:
final userDeviceKeys = client.userDeviceKeys['@userid:domain.abc'];
print(userDeviceKeys.verified);
```

You can loop over all users in a room like this:

```dart
Future<List<User>> warnAboutChangedKeys(Room room) async {
    if (!room.encrypted) return [];

    final users = await room.requestParticipants();

    for(final user in users) {
        if (user.id == room.client.userID) continue;
        final keys = room.client.userDeviceKeys[user.id];

        if (keys.masterKey == null) {
            print('User without cross signing detected!');
            continue;
        }

        if (keys.verified == UserVerifiedStatus.unknown) {
            keys.trustOnFirstUse();
            print('Trust on first use for ${user.id}');
            continue;
        }

        if (keys.verified == UserVerifiedStatus.publicKeyHasChanged) {
            keys.trustOnFirstUse();
            print('The public key of ${user.id} has been changed!');
            // TODO: Inform the user in the GUI!
            continue;
        }
    }
}
```

Then inform the user about those users.
This should be done before every message sending into the room.