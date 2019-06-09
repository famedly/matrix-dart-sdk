# fluffyfluttermatrix

Dead simple Flutter widget to use Matrix.org in your Flutter app.

## How to use this

1. Use the Matrix widget as root for your widget tree:

```dart
import 'package:flutter/material.dart';
import 'package:fluffyfluttermatrix/fluffyfluttermatrix.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FluffyMatrix(
      child: MaterialApp(
        title: 'Welcome to Flutter'
      ),
    );
  }
}

```

2. Access the MatrixState object by calling Matrix.of with your current BuildContext:

```dart
Client matrix = Matrix.of(context);
```

3. Connect to a Matrix Homeserver and listen to the streams:

```dart
matrix.homeserver = "https://yourhomeserveraddress";

matrix.onLoginStateChanged.stream.listen((bool loginState){ 
  print("LoginState: ${loginState.toString()}");
});

matrix.onEvent.stream.listen((EventUpdate eventUpdate){ 
  print("New event update!");
});

matrix.onRoomUpdate.stream.listen((RoomUpdate eventUpdate){ 
  print("New room update!");
});

final loginResp = await matrix.jsonRequest(
  type: "POST",
  action: "/client/r0/login",
  data: {
    "type": "m.login.password",
    "user": _usernameController.text,
    "password": _passwordController.text,
    "initial_device_display_name": "Fluffy Matrix Client"
  }
);

matrix.connect(
  newToken: loginResp["token"],
  newUserID: loginResp["user_id"],
  newHomeserver: matrix.homeserver,
  newDeviceName: "Fluffy Matrix Client",
  newDeviceID: loginResp["device_id"],
  newMatrixVersions: ["r0.4.0"],
  newLazyLoadMembers: false
);
```

4. Send a message to a Room:

```dart
final resp = await jsonRequest(
    type: "PUT",
    action: "/r0/rooms/!fjd823j:example.com/send/m.room.message/$txnId",
    data: {
        "msgtype": "m.text",
        "body": "hello"
    }
);
```