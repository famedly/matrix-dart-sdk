import 'dart:math';

import 'package:matrix/matrix.dart';

extension GenerateDeviceIdExtension on Client {
  /// Checks whether the client already generated a device ID and creates one in case there is no.
  /// Returns the generated device ID.
  ///
  /// This is particularly useful when authenticating via OIDC since clients must supply a locally generated device ID for login via OIDC.
  /// - [MSC 2964](https://github.com/matrix-org/matrix-spec-proposals/pull/2964) defines the code grant flow requiring a device ID in the OAuth2.0 scopes
  /// - [MSC 2967](https://github.com/matrix-org/matrix-spec-proposals/pull/2967) requires a device ID to be present for requesting OAuth2.0 scopes
  Future<String> oidcEnsureDeviceId([bool enforceNewDevice = false]) async {
    if (!enforceNewDevice) {
      final storedDeviceId = deviceID ?? await database.getDeviceId();
      if (storedDeviceId is String) {
        Logs().d('[OIDC] Restoring device ID $storedDeviceId.');
        return storedDeviceId;
      }
    }

    // [MSC 1597](https://github.com/matrix-org/matrix-spec-proposals/pull/1597)
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
