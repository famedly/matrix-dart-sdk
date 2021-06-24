// @dart=2.9
import 'package:matrix_api_lite/src/matrix_api.dart';

void main() async {
  final api = MatrixApi(homeserver: Uri.parse('https://matrix.org'));
  final capabilities = await api.requestServerCapabilities();
  print(capabilities.toJson());
}
