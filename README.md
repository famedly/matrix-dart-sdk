+++ This SDK is under development and highly experimental +++

# famedlysdk

Matrix SDK for the famedly talk app written in dart.

## API

The API is documented here: [famedly.gitlab.io/famedlysdk](https://famedly.gitlab.io/famedlysdk/)

## How to use this

1. Import the sdk

```yaml
  famedlysdk:
    git:
      url: https://gitlab.com/famedly/famedlysdk.git
      ref: 77be6102f6cbb2e01adc28f9caa3aa583f914235
```

(Optional) Import the store

```yaml
   famedlysdk_store_sqflite:
    git:
      url: https://gitlab.com/famedly/libraries/famedlysdk-store.git
      ref: 17fbbed1ea9b04ca041e9479d4e74bb4d2c78d55
```

```dart
import 'package:flutter/material.dart';
import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk-store/ famedlysdk_store_sqflite.dart'; // Optional
```

2. Create a new client:

```dart
Client matrix = Client("HappyChat");
```

Or with store:

```dart
Client matrix = Client("HappyChat", store: Store(this));
```

3. Connect to a Matrix Homeserver and listen to the streams:

```dart
matrix.connection.onLoginStateChanged.stream.listen((bool loginState){ 
  print("LoginState: ${loginState.toString()}");
});

matrix.connection.onEvent.stream.listen((EventUpdate eventUpdate){ 
  print("New event update!");
});

matrix.connection.onRoomUpdate.stream.listen((RoomUpdate eventUpdate){ 
  print("New room update!");
});

final bool serverValid = await matrix.checkServer("https://yourhomeserver.abc");

final bool loginValid = await matrix.login("username", "password");
```

4. Send a message to a Room:

```dart
final resp = await matrix.connection.jsonRequest(
    type: "PUT",
    action: "/r0/rooms/!fjd823j:example.com/send/m.room.message/$txnId",
    data: {
        "msgtype": "m.text",
        "body": "hello"
    }
);
```

## Development

### Regenerating JSON Classes

To regenerate the part files of JSON Classes you need to run this command:

```bash
flutter pub run build_runner build
```