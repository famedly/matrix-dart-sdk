import 'package:matrix/matrix_api_lite/utils/logs.dart';

bool isVersionGreaterThanOrEqualTo(String version, String target) {
  try {
    final versionParts =
        version.substring(1).split('.').map(int.parse).toList();
    final targetParts = target.substring(1).split('.').map(int.parse).toList();

    for (int i = 0; i < versionParts.length; i++) {
      if (i >= targetParts.length) return true; // reached the end, both equal
      if (versionParts[i] > targetParts[i]) return true; // ver greater
      if (versionParts[i] < targetParts[i]) return false; // tar greater
    }

    return true;
  } catch (e, s) {
    Logs().e(
      '[_isVersionGreaterThanOrEqualTo] Failed to parse version $version',
      e,
      s,
    );
    return false;
  }
}
