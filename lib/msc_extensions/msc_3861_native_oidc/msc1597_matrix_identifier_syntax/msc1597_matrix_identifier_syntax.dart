import 'dart:math';

import 'package:matrix/matrix.dart';

extension GenerateDeviceIdExtension on Client {
  /// MSC 2964 & MSC 2967
  Future<String> oidcEnsureDeviceId([bool enforceNewDevice = false]) async {
    if (!enforceNewDevice) {
      final storedDeviceId = await database.getDeviceId();
      if (storedDeviceId is String) {
        Logs().d('[OIDC] Restoring device ID $storedDeviceId.');
        return storedDeviceId;
      }
    }

    // MSC 1597
    //
    // [A-Z] but without I and O (smth too similar to 1 and 0)
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    final deviceId = String.fromCharCodes(
      List.generate(
        10,
        (_) => chars.codeUnitAt(Random().nextInt(chars.length)),
      ),
    );

    await database.storeDeviceId(deviceId);
    Logs().d('[OIDC] Generated device ID $deviceId.');
    return deviceId;
  }
}
