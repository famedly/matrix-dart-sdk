// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final client = Client(
    'Matrix Example Chat',
    // The SDK stores everything in this database. We back it with a sqflite
    // file on native platforms; on web the SDK falls back to IndexedDB.
    database: await MatrixSdkDatabase.init(
      'matrix_example_chat',
      database: kIsWeb ? null : await _openDatabase(),
    ),
  );

  // Restores a previous session from the database (if any) and starts syncing.
  await client.init();

  runApp(MatrixExampleChat(client: client));
}

Future<sqflite.Database> _openDatabase() async {
  final directory = await getApplicationSupportDirectory();
  return sqflite.openDatabase(p.join(directory.path, 'matrix_example_chat.db'));
}

/// The root widget. It holds the [Client] and shows either the login page or
/// the chat list, depending on whether we are logged in.
class MatrixExampleChat extends StatelessWidget {
  final Client client;

  const MatrixExampleChat({required this.client, super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<Client>.value(
      value: client,
      child: MaterialApp(
        title: 'Matrix Example Chat',
        theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
        home: StreamBuilder(
          stream: client.onLoginStateChanged.stream,
          builder: (context, snapshot) {
            return client.isLogged() ? const RoomListPage() : const LoginPage();
          },
        ),
      ),
    );
  }
}

/// Lets the user log in with a homeserver, username and password.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _homeserver = TextEditingController(text: 'matrix.org');
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    final client = context.read<Client>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _loading = true);
    try {
      await client.checkHomeserver(Uri.https(_homeserver.text.trim()));
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: _username.text.trim()),
        password: _password.text,
      );
      // On success the login state stream rebuilds the root and shows the chats.
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _homeserver,
              enabled: !_loading,
              decoration: const InputDecoration(
                prefixText: 'https://',
                labelText: 'Homeserver',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _username,
              enabled: !_loading,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              enabled: !_loading,
              obscureText: true,
              onSubmitted: (_) => _login(),
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _login,
              child: Text(_loading ? 'Logging in...' : 'Login'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the list of rooms the user has joined.
class RoomListPage extends StatelessWidget {
  const RoomListPage({super.key});

  void _openRoom(BuildContext context, Room room) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RoomPage(room: room)),
    );
  }

  /// Asks for a user ID, room ID/alias or room name and then starts a direct
  /// chat, joins the room or creates a new room accordingly.
  Future<void> _newChat(BuildContext context) async {
    final client = context.read<Client>();
    final messenger = ScaffoldMessenger.of(context);

    final input = await showDialog<String>(
      context: context,
      builder: (_) => const _NewChatDialog(),
    );
    if (input == null || input.isEmpty) return;

    try {
      final String roomId;
      if (input.startsWith('@')) {
        roomId = await client.startDirectChat(input);
      } else if (input.startsWith('#') || input.startsWith('!')) {
        roomId = await client.joinRoom(input);
      } else {
        roomId = await client.createGroupChat(groupName: input);
      }
      final room = client.getRoomById(roomId);
      if (room != null && context.mounted) _openRoom(context, room);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = context.read<Client>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          PopupMenuButton(
            itemBuilder: (_) => [
              PopupMenuItem(onTap: client.logout, child: const Text('Logout')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _newChat(context),
        tooltip: 'New chat',
        child: const Icon(Icons.add),
      ),
      // Rebuild the list whenever a sync updates the rooms.
      body: StreamBuilder(
        stream: client.onSync.stream,
        builder: (context, _) {
          final rooms = client.rooms;
          if (rooms.isEmpty) {
            return const Center(
                child: Text('No chats yet. Tap + to start one.'));
          }
          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, i) {
              final room = rooms[i];
              final name = room.getLocalizedDisplayname();
              return ListTile(
                leading: CircleAvatar(child: Text(_initial(name))),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  room.lastEvent?.body ?? 'No messages',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: room.notificationCount > 0
                    ? Badge(label: Text('${room.notificationCount}'))
                    : null,
                onTap: () => _openRoom(context, room),
              );
            },
          );
        },
      ),
    );
  }
}

/// A simple text field dialog used to start a new chat.
class _NewChatDialog extends StatefulWidget {
  const _NewChatDialog();

  @override
  State<_NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<_NewChatDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New chat'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        onSubmitted: (text) => Navigator.of(context).pop(text.trim()),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: '@user:server / #alias:server / Room name',
          helperMaxLines: 3,
          helperText: 'A user ID starts a direct chat, a room ID/alias joins a '
              'room, anything else creates a new room.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// Shows the timeline of a single room and lets the user send messages.
class RoomPage extends StatefulWidget {
  final Room room;

  const RoomPage({required this.room, super.key});

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  final _input = TextEditingController();
  Timeline? _timeline;

  @override
  void initState() {
    super.initState();
    // `onUpdate` fires on every change, so we just rebuild the whole list.
    widget.room
        .getTimeline(onUpdate: () => setState(() {}))
        .then((timeline) => setState(() => _timeline = timeline));
  }

  @override
  void dispose() {
    _timeline?.cancelSubscriptions();
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    widget.room.sendTextEvent(text);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final timeline = _timeline;
    // Only show actual messages; hide membership/room-setup state events.
    final messages =
        timeline?.events.where((e) => e.type == EventTypes.Message).toList() ??
            [];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.getLocalizedDisplayname()),
        actions: [
          PopupMenuButton(
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: () async {
                  await widget.room.leave();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Leave room'),
              ),
            ],
          ),
        ],
      ),
      body: timeline == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (_, i) => _MessageTile(event: messages[i]),
                  ),
                ),
                const Divider(height: 1),
                _MessageInput(controller: _input, onSend: _send),
              ],
            ),
    );
  }
}

/// A single message shown as the sender, time and text.
class _MessageTile extends StatelessWidget {
  final Event event;

  const _MessageTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(event.originServerTs).format(context);
    return Opacity(
      opacity: event.status.isSent ? 1 : 0.5,
      child: ListTile(
        title: Row(
          children: [
            Expanded(
                child:
                    Text(event.senderFromMemoryOrFallback.calcDisplayname())),
            Text(time, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        subtitle: Text(event.body),
      ),
    );
  }
}

/// The text field and send button at the bottom of a room.
class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _MessageInput({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(hintText: 'Send message'),
            ),
          ),
          IconButton(icon: const Icon(Icons.send_outlined), onPressed: onSend),
        ],
      ),
    );
  }
}

String _initial(String name) =>
    name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
