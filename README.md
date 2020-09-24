# Matrix Dart SDK

The Matrix Dart SDK can be used as a single component or in combination with other modules.

## Overview

![Client Architecture](/doc/images/Architecture.png "Client Architecture")

## Documentation

* [API](https://famedly.gitlab.io/famedlysdk/api/index.html)
* [Documentation](https://famedly.gitlab.io/famedlysdk/doc/index.html) !WIP!

## Getting started

### 1. Import the SDK

```yaml
  famedlysdk:
    git:
      url: https://gitlab.com/famedly/famedlysdk.git
```

```dart
import 'package:flutter/material.dart';
import 'package:famedlysdk/famedlysdk.dart';
```

### 2. Create a new Client

```dart
Client matrix = Client("SecureChat");
```

### 3. Connect to a Matrix Homeserver and listen to the streams

```dart
matrix.onLoginStateChanged.stream.listen((bool loginState){ 
  print("LoginState: ${loginState.toString()}");
});

matrix.onEvent.stream.listen((EventUpdate eventUpdate){ 
  print("New event update!");
});

matrix.onRoomUpdate.stream.listen((RoomUpdate eventUpdate){ 
  print("New room update!");
});

final bool serverValid = await matrix.checkServer("https://yourhomeserver.abc");

final bool loginValid = await matrix.login("username", "password");
```

### 4. Send a message to a Room:

```dart
final resp = await matrix.jsonRequest(
    type: "PUT",
    action: "/r0/rooms/!fjd823j:example.com/send/m.room.message/$txnId",
    data: {
        "msgtype": "m.text",
        "body": "hello"
    }
);
```
