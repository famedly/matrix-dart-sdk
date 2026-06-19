<!--
SPDX-FileCopyrightText: 2019-Present Famedly GmbH

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Matrix Example Chat

A minimal Flutter example app for the [Matrix Dart SDK](https://pub.dev/packages/matrix).
The whole app lives in a single source file: [`lib/main.dart`](lib/main.dart).

It demonstrates the essentials:

- Instantiating a `Client` with a persistent database in an async `main()`.
- Holding the `Client` in the root widget and passing it down via `provider`.
- Showing the login page or the chat list on start depending on the login state.
- A login page, a chat list page and a chat page.
- A floating action button to start a direct chat, join a room by ID/alias or
  create a new room.
- Logout and "leave room" actions via three-dot menus.

## Run it

```sh
cd example
flutter pub get
flutter run
```

The app works on all Flutter platforms. On native platforms the SDK database is
backed by `sqflite`; on web it falls back to IndexedDB.

> Note: For end-to-end encryption you additionally need to initialise
> [`flutter_vodozemac`](https://pub.dev/packages/flutter_vodozemac). This example
> keeps things simple and does not set it up.
