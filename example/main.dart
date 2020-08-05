import 'package:famedlysdk/famedlysdk.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(FamedlySdkExampleApp());
}

class FamedlySdkExampleApp extends StatelessWidget {
  static Client client = Client('Famedly SDK Example Client', debug: true);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Famedly SDK Example App',
      home: LoginView(),
    );
  }
}

class LoginView extends StatefulWidget {
  @override
  _LoginViewState createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _homeserverController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _error;

  void _loginAction() async {
    setState(() => _isLoading = true);
    setState(() => _error = null);
    try {
      if (await FamedlySdkExampleApp.client
              .checkServer(_homeserverController.text) ==
          false) {
        throw (Exception('Server not supported'));
      }
      if (await FamedlySdkExampleApp.client.login(
            _usernameController.text,
            _passwordController.text,
          ) ==
          false) {
        throw (Exception('Username or password incorrect'));
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => ChatListView()),
        (route) => false,
      );
    } catch (e) {
      setState(() => _error = e.toString());
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _homeserverController,
            readOnly: _isLoading,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Homeserver',
              hintText: 'https://matrix.org',
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _usernameController,
            readOnly: _isLoading,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Username',
              hintText: '@username:domain',
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: true,
            readOnly: _isLoading,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: '****',
              errorText: _error,
            ),
          ),
          SizedBox(height: 8),
          RaisedButton(
            child: _isLoading ? LinearProgressIndicator() : Text('Login'),
            onPressed: _isLoading ? null : _loginAction,
          ),
        ],
      ),
    );
  }
}

class ChatListView extends StatefulWidget {
  @override
  _ChatListViewState createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chats'),
      ),
      body: StreamBuilder(
        stream: FamedlySdkExampleApp.client.onSync.stream,
        builder: (c, s) => ListView.builder(
          itemCount: FamedlySdkExampleApp.client.rooms.length,
          itemBuilder: (BuildContext context, int i) {
            final room = FamedlySdkExampleApp.client.rooms[i];
            return ListTile(
              title: Text(room.displayname + ' (${room.notificationCount})'),
              subtitle: Text(room.lastMessage, maxLines: 1),
              leading: CircleAvatar(
                backgroundImage: NetworkImage(room.avatar.getThumbnail(
                  FamedlySdkExampleApp.client,
                  width: 64,
                  height: 64,
                )),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatView(room: room),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ChatView extends StatefulWidget {
  final Room room;

  const ChatView({Key key, @required this.room}) : super(key: key);

  @override
  _ChatViewState createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _controller = TextEditingController();

  void _sendAction() {
    print('Send Text');
    widget.room.sendTextEvent(_controller.text);
    _controller.clear();
  }

  Timeline timeline;

  Future<bool> getTimeline() async {
    timeline ??=
        await widget.room.getTimeline(onUpdate: () => setState(() => null));
    return true;
  }

  @override
  void dispose() {
    timeline?.cancelSubscriptions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<Object>(
            stream: widget.room.onUpdate.stream,
            builder: (context, snapshot) {
              return Text(widget.room.displayname);
            }),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder(
              future: getTimeline(),
              builder: (context, snapshot) => !snapshot.hasData
                  ? Center(
                      child: CircularProgressIndicator(),
                    )
                  : ListView.builder(
                      reverse: true,
                      itemCount: timeline.events.length,
                      itemBuilder: (BuildContext context, int i) => Opacity(
                        opacity: timeline.events[i].status != 2 ? 0.5 : 1,
                        child: ListTile(
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  timeline.events[i].sender.calcDisplayname(),
                                ),
                              ),
                              Text(
                                timeline.events[i].originServerTs
                                    .toIso8601String(),
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          subtitle: Text(timeline.events[i].body),
                          leading: CircleAvatar(
                            child: timeline.events[i].sender?.avatarUrl == null
                                ? Icon(Icons.person)
                                : null,
                            backgroundImage:
                                timeline.events[i].sender?.avatarUrl != null
                                    ? NetworkImage(
                                        timeline.events[i].sender?.avatarUrl
                                            ?.getThumbnail(
                                          FamedlySdkExampleApp.client,
                                          width: 64,
                                          height: 64,
                                        ),
                                      )
                                    : null,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          Container(
            height: 60,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      labelText: 'Send a message ...',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendAction,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
