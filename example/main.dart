import 'package:famedlysdk/famedlysdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(FamedlySdkExampleApp());
}

class FamedlySdkExampleApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Provider<Client>(
      create: (_) => Client('Famedly SDK Example App'),
      child: Builder(
        builder: (context) => MaterialApp(
          title: 'Famedly SDK Example App',
          home: StreamBuilder<LoginState>(
            stream: Provider.of<Client>(context).onLoginStateChanged.stream,
            builder:
                (BuildContext context, AsyncSnapshot<LoginState> snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text(snapshot.error.toString()));
              }
              if (snapshot.data == LoginState.logged) {
                return ChatListView();
              }
              return LoginView();
            },
          ),
        ),
      ),
    );
  }
}

class LoginView extends StatefulWidget {
  @override
  _LoginViewState createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _usernameController = TextEditingController(),
      _passwordController = TextEditingController(),
      _domainController = TextEditingController();

  String _errorText;

  bool _isLoading = false;

  void _loginAction(Client client) async {
    setState(() {
      _errorText = null;
      _isLoading = true;
    });
    try {
      await client.checkHomeserver(_domainController.text);
      await client.login(
        user: _usernameController.text,
        password: _passwordController.text,
      );
    } catch (e) {
      setState(() => _errorText = e.toString());
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final client = Provider.of<Client>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Famedly SDK Example App'),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          TextField(
            controller: _usernameController,
            readOnly: _isLoading,
            autocorrect: false,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Username',
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            readOnly: _isLoading,
            autocorrect: false,
            obscureText: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Password',
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _domainController,
            readOnly: _isLoading,
            autocorrect: false,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Password',
              hintText: 'https://matrix.org',
              errorText: _errorText,
              errorMaxLines: 4,
            ),
          ),
          SizedBox(height: 16),
          RaisedButton(
            child: _isLoading ? LinearProgressIndicator() : Text('Login'),
            onPressed: _isLoading ? null : () => _loginAction(client),
          ),
        ],
      ),
    );
  }
}

class ChatListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final client = Provider.of<Client>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Chats'),
      ),
      body: StreamBuilder(
        stream: client.onSync.stream,
        builder: (context, _) => ListView.builder(
          itemCount: client.rooms.length,
          itemBuilder: (BuildContext context, int i) => ListTile(
            leading: CircleAvatar(
              backgroundImage: client.rooms[i].avatar == null
                  ? null
                  : NetworkImage(
                      client.rooms[i].avatar.getThumbnail(
                        client,
                        width: 64,
                        height: 64,
                      ),
                    ),
            ),
            title: Text(client.rooms[i].displayname),
            subtitle: Text(client.rooms[i].lastMessage),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatView(roomId: client.rooms[i].id),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChatView extends StatelessWidget {
  final String roomId;

  const ChatView({Key key, @required this.roomId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final client = Provider.of<Client>(context);
    final TextEditingController _sendController = TextEditingController();
    return StreamBuilder<Object>(
        stream: client.onSync.stream,
        builder: (context, _) {
          final room = client.getRoomById(roomId);
          return Scaffold(
            appBar: AppBar(
              title: Text(room.displayname),
            ),
            body: SafeArea(
              child: FutureBuilder<Timeline>(
                future: room.getTimeline(),
                builder:
                    (BuildContext context, AsyncSnapshot<Timeline> snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final timeline = snapshot.data;
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          reverse: true,
                          itemCount: timeline.events.length,
                          itemBuilder: (BuildContext context, int i) {
                            final event = timeline.events[i];
                            final sender = event.sender;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: sender.avatarUrl == null
                                    ? null
                                    : NetworkImage(
                                        sender.avatarUrl.getThumbnail(
                                          client,
                                          width: 64,
                                          height: 64,
                                        ),
                                      ),
                              ),
                              title: Text(sender.calcDisplayname()),
                              subtitle: Text(event.body),
                            );
                          },
                        ),
                      ),
                      Divider(height: 1),
                      Container(
                        height: 56,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _sendController,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.send),
                              onPressed: () {
                                room.sendTextEvent(_sendController.text);
                                _sendController.clear();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        });
  }
}
