import 'package:matrix/matrix.dart';

extension IceServersExtension on Client {
  Future<List<Map<String, dynamic>>> getIceSevers() async {
    TurnServerCredentials? turnServerCredentials;
    try {
      turnServerCredentials = await getTurnServer();
    } catch (e) {
      Logs().v('[VOIP] getTurnServerCredentials error => ${e.toString()}');
    }

    if (turnServerCredentials == null) {
      return [];
    }

    return [
      {
        'username': turnServerCredentials.username,
        'credential': turnServerCredentials.password,
        'urls': turnServerCredentials.uris
      }
    ];
  }
}
