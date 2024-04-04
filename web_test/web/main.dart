import 'package:matrix/matrix.dart';

Future<void> main() async {
  final client = Client('web_test');
  await client.init();
}
