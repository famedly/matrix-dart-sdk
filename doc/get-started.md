Follow these steps to get started with your first Matrix Client.

## Step 1: Add dependencies

In your `pubspec.yaml` file add the following dependencies:

```yaml
  matrix: <latest-version>
  # (Optional) If you plan to use the SDK in a Flutter application on IO
  # you need sqflite or sqflite_ffi:
  sqflite: <latest-version>
  # (Optional) For end to end encryption, please head on the
  # encryption guide and add these dependencies:
  flutter_vodozemac: <latest-version>
```

## Step 2: Create the client

```dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:matrix/matrix.dart';

final client = Client(
    '<Client Name>',
    database: await MatrixSdkDatabase.init(
        '<Database Name>',
        database: await databaseFactoryFfi.openDatabase(':memory:'),
        sqfliteFactory: databaseFactoryFfi,
    ),
);
```

### Alternative: Create a persistent database with SQFlite:

```dart
import 'package:sqflite/sqflite.dart';
import 'package:matrix/matrix.dart';

final client = Client(
    '<Client Name>',
    database: await MatrixSdkDatabase.init(
        '<Database Name>',
        database: await openDatabase('/path/to/database.sqlite'),
    ),
);
```

## Step 3: Login

```dart
// Connect to a homeserver before login:
final homeserver = Uri.parse('https://matrix.org');
await client.checkHomeserver(homeserver);

await client.login(
    LoginType.password,
    user: AuthenticationUserIdentifier(user: '<your-username>'),
    password: '<your-password>',
);
```

## Step 4: Create a new room

```dart
// Start a new DM room or return an existing room with a user
final roomId = await client.startDirectChat('<user-id>');

// Start a new group chat
final roomId = await client.createGroupChat(name: '<group-name>');
```

## Step 5: Send messages

```dart
// Get a specific room by room ID or iterate over `client.rooms`:
final room = client.getRoomById('<room-id>');
// Or get the DM room for a user:
final dmRoom = client.getDirectChatFromUserId('<user-id>');

// Send a normal text message into the room:
await room.sendTextEvent('<your-message>');
```

## Step 6: Receive messages

```dart
// Load the timeline of a room:
final timeline = await room.getTimeline(
    onUpdate: reloadYourGui(),
    onInsert: (i) => print('New message!'),
);

// Print all messages in the timeline to the console
for(final event in timeline.events) print(event.calcLocalizedBodyFallback());
```