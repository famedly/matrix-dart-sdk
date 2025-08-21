import 'package:matrix/matrix.dart';

extension Msc4191AccountManagementExtension on Client {
  Uri? getOidcAccountManagementUri({
    OidcAccountManagementActions? action,
    String? idTokenHint,
    String? deviceId,
  }) {
    final providerMetadata = oidcAuthMetadata;

    final rawUri = providerMetadata?['account_management_uri'];
    if (rawUri is! String) {
      return null;
    }

    final uri = Uri.tryParse(rawUri)?.resolveUri(
      Uri(
        queryParameters: {
          if (action is OidcAccountManagementActions) 'action': action.action,
          if (deviceId is String) 'device_id': deviceId,
          if (idTokenHint is String) 'id_token_hint': idTokenHint,
        },
      ),
    );
    return uri;
  }
}

enum OidcAccountManagementActions {
  profile('profile'),
  sessionsList('sessions_list'),
  sessionView('session_view'),
  sessionEnd('session_end'),
  accountDeactivate('account_deactivate'),
  crossSigningReset('cross_signing_reset');

  const OidcAccountManagementActions(this.name);

  /// name as it appears in the metadata
  final String name;

  /// action as it is used for deep linking
  String get action => 'org.matrix.$name';
}
