# Implement \[matrix\] OIDC using the Matrix Dart SDK

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:matrix/matrix.dart';
import 'package:url_launcher:url_launcher.dart';

Future<void> main() async {
  final client = Client(
    // [...]
  );

  await client.checkHomeserver(myHomeserver);

  final name = 'My [matrix] client on web';

  final registrationData = OidcDynamicRegistrationData.localized(
    contacts: {myOidcAdminContact},
    url: 'https://example.com',
    defaultLocale: myDefaultLocale,
    localizations: {
      'fr_FR': LocalizedOidcClientMetadata(
        // [...]
      )
    },
    redirect: kIsWeb
        ? { 'http://localhost:0'}
        : {
      Uri.parse('com.example:/oauth2redirect/'),
      Uri.parse('http://localhost/oauth2redirect/'),
    },
    applicationType: kIsWeb ? 'web' : 'native',
  );

  final oidcClientId = await client.oidcEnsureDynamicClientId(
    registrationData,
  );

  // You can e.g. use `package:app_links` to forward the called deep link into this completer
  final nativeCompleter = Completer<OidcCallbackResponse>();

  await client.oidcAuthorizationGrantFlow(
    nativeCompleter: nativeCompleter,
    oidcClientId: oidcClientId,
    redirectUri: client.oAuth2RedirectUri,
    launchOAuth2Uri: launchUrl,
    responseMode: kIsWeb ? 'fragment' : 'query',
    prompt: 'consent',
    initialDeviceDisplayName: name,
    enforceNewDeviceId: true,
  );
}
```
