import 'package:matrix/matrix.dart';

extension Msc4191AccountManagementExtension on Client {
  Future<Uri?> getOidcAccountManagementUri({
    OidcAccountManagementActions? action,
    String? idTokenHint,
    String? deviceId,
  }) async {
    final providerMetadata = await getAuthMetadata();

    final managementUri = providerMetadata.accountManagementUri;
    if (managementUri == null) {
      return null;
    }

    final supportedActions = providerMetadata.accountManagementActionsSupported;

    final uri = managementUri.resolveUri(
      Uri(
        queryParameters: {
          if (action is OidcAccountManagementActions &&
              supportedActions != null &&
              supportedActions.contains(action.name))
            'action': action.action,
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
