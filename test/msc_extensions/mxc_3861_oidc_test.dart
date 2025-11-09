import 'package:test/test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:matrix/matrix.dart';
import '../fake_database.dart';

void main() {
  group('MXC 3861 OIDC', tags: 'olm', () {
    test('Test OIDC Login Flow', () async {
      await vod.init(
        wasmPath: './pkg/',
        libraryPath: './rust/target/debug/',
      );
      final client = Client(
        logLevel: Level.verbose,
        'testclient',
        httpClient: FakeMatrixApi(),
        database: await getDatabase(),
        onSoftLogout: (client) => client.refreshAccessToken(),
      );
      FakeMatrixApi.client = client;
      await client.checkHomeserver(
        Uri.parse('https://fakeServer.notExisting'),
        checkWellKnown: false,
      );
      final redirectUri = Uri.http('localhost:123456');

      // Uris must be based on Client Uri:
      try {
        await client.registerOidcClient(
          redirectUris: [redirectUri],
          applicationType: OidcApplicationType.native,
          clientInformation: OidcClientInformation(
            clientName: 'Test Client',
            clientUri: Uri.https('matrix-client.invalid'),
            logoUri: Uri.https('matrix.org', '/logo.png'),
            tosUri: Uri.https('famedly.de', 'tos'),
            policyUri: Uri.https('fluffy.chat', 'privacy'),
          ),
        );
        fail('Should throw');
      } catch (e) {
        expect(e, isException);
      }

      // Uris must be https
      try {
        await client.registerOidcClient(
          redirectUris: [redirectUri],
          applicationType: OidcApplicationType.native,
          clientInformation: OidcClientInformation(
            clientName: 'Test Client',
            clientUri: Uri.http('matrix-client.invalid'),
            logoUri: null,
            tosUri: null,
            policyUri: null,
          ),
        );
        fail('Should throw');
      } catch (e) {
        expect(e, isException);
      }

      final oidcClientData = await client.registerOidcClient(
        redirectUris: [redirectUri],
        applicationType: OidcApplicationType.native,
        clientInformation: OidcClientInformation(
          clientName: 'Test Client',
          clientUri: Uri.https('matrix-client.invalid'),
          logoUri: null,
          tosUri: null,
          policyUri: null,
        ),
      );
      expect(oidcClientData.clientId, '1234');
      expect(oidcClientData.clientInformation.clientName, 'Test Client');

      final session = await client.initOidcLoginSession(
        oidcClientData: oidcClientData,
        redirectUri: redirectUri,
      );

      await client.oidcLogin(
        session: session,
        code: 'faketestcode',
        state: session.state,
      );

      expect(client.isLogged(), true);
    });
  });
}
