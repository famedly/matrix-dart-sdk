# famedlysdk

Matrix SDK for the famedly talk app written in dart.

## How to use this

1. Import the sdk

```yaml
  famedlysdk:
    git:
      url: https://gitlab.com/famedly/famedlysdk.git
      ref: 77be6102f6cbb2e01adc28f9caa3aa583f914235
```

```dart
import 'package:flutter/material.dart';
import 'package:famedlysdk/famedlysdk.dart';

```

2. Access the MatrixState object by calling Matrix.of with your current BuildContext:

```dart
Client matrix = Client("famedly talk");
```

3. Connect to a Matrix Homeserver and listen to the streams:

```dart
matrix.homeserver = "https://yourhomeserveraddress";

matrix.connection.onLoginStateChanged.stream.listen((bool loginState){ 
  print("LoginState: ${loginState.toString()}");
});

matrix.connection.onEvent.stream.listen((EventUpdate eventUpdate){ 
  print("New event update!");
});

matrix.connection.onRoomUpdate.stream.listen((RoomUpdate eventUpdate){ 
  print("New room update!");
});

final loginResp = await matrix.connection.jsonRequest(
  type: "POST",
  action: "/client/r0/login",
  data: {
    "type": "m.login.password",
    "user": _usernameController.text,
    "password": _passwordController.text,
    "initial_device_display_name": "famedly talk"
  }
);

matrix.connection.connect(
  newToken: loginResp["token"],
  newUserID: loginResp["user_id"],
  newHomeserver: matrix.homeserver,
  newDeviceName: "famedly talk",
  newDeviceID: loginResp["device_id"],
  newMatrixVersions: ["r0.4.0"],
  newLazyLoadMembers: false
);
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