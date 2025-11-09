Follow these steps to login with Matrix native OIDC. Your app must be
capable of opening a website (e.g. in an in-app-browser or for web clients in a new tab)
and retrieve a redirect URI. We recommend investigating into a package
like [flutter_web_auth_2](https://pub.dev/packages/flutter_web_auth_2) for
this task.

> Disclaimer: Support is still in a MSC and therefore considered as beta.

### Step 1: Fetch the auth metadata

You first need to fetch the auth metadata from a given homeserver. The
homeserver must support the `/auth_metadata` endpoint which was introduced
in the Matrix Spec 1.15:

```dart
final (_,_,_,authMetadata) = await client.checkHomserver(Uri.https('matrix.org'));
```

### Step 2: Dynamic Client registration

You need to register an OIDC client first. There you can specify some
metadata about your client:

```dart
final oidcClientData = await client.registerOidcClient(
    redirectUris: [Uri.parse('http://localhost:123456')],
    applicationType: OidcApplicationType.native,
    clientInformation: OidcClientInformation(clientUri: Uri.https('my-client-website.com')),
);
```

### Step 3: Create a new OIDC Login session

This prepares the code verifier and state.

```dart
final session = await client.initOidcLoginSession(
    oidcClientData: oidcClientData,
    redirectUri: Uri.parse('http://localhost:123456'),
);
```

### Step 4: Open a browser in your app and get the code returned

If you are using Flutter you can use a package like [flutter_web_auth_2](https://pub.dev/packages/flutter_web_auth_2):

```dart
final returnUrlString = await FlutterWebAuth2.authenticate(
    url: session.authenticationUri.toString(),
);

final returnUrl = Uri.parse(returnUrlString);

final queryParameters = returnUrl.hasFragment
    ? Uri.parse(returnUrl.fragment).queryParameters
    : returnUrl.queryParameters;

final code = queryParameters['code'] as String;
final state = queryParameters['state'] as String;
```

### Step 5: Login with OIDC

Now that you have the `code` you can just login:

```dart
await client.oidcLogin(
    session: session,
    code: code,
    state: state,
);
```