// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';
import 'package:test/test.dart';

import 'fake_client.dart';

void main() {
  group('Soft logout lifecycle', () {
    var refreshGeneration = 0;

    void prepRefreshEndpoint(FakeMatrixApi fakeApi, {bool success = true}) {
      fakeApi.api['POST']!['/client/v3/refresh'] = success
          ? (_) {
              refreshGeneration++;
              return {
                'access_token': 'access_token_$refreshGeneration',
                'expires_in_ms': 500,
                'refresh_token': 'refresh_token_$refreshGeneration',
              };
            }
          : (_) => {
              'errcode': 'M_UNKNOWN_TOKEN',
              'error': 'invalid refresh token',
            };
    }

    test(
      'refresh, rejected refresh clears session, re-login recovers',
      () async {
        refreshGeneration = 0;
        final client = await getClient();
        final fakeApi = FakeMatrixApi.currentApi!;

        final loginStates = <LoginState>[];
        client.onLoginStateChanged.stream.listen(loginStates.add);

        var softLogouts = 0;
        client.onSoftLogout = (c) {
          softLogouts++;
          return c.refreshAccessToken();
        };

        prepRefreshEndpoint(fakeApi);
        await client.refreshAccessToken();
        expect(softLogouts, 0);
        expect(client.accessToken, 'access_token_1');
        expect(client.accessTokenExpiresAt, isNotNull);

        await client.ensureNotSoftLoggedOut();
        expect(softLogouts, 1);
        expect(client.accessToken, 'access_token_2');
        final storedAfterRefresh = await client.database.getClient(
          client.clientName,
        );
        expect(
          storedAfterRefresh?.tryGet<String>('refresh_token'),
          'refresh_token_2',
        );
        expect(loginStates, [LoginState.softLoggedOut, LoginState.loggedIn]);
        loginStates.clear();

        prepRefreshEndpoint(fakeApi, success: false);
        final loggedOut = client.onLoginStateChanged.stream.firstWhere(
          (state) => state == LoginState.loggedOut,
        );
        await expectLater(
          client.ensureNotSoftLoggedOut(),
          throwsA(isA<MatrixException>()),
        );
        await loggedOut;
        expect(softLogouts, 2);
        expect(client.isLogged(), isFalse);
        expect(loginStates, [LoginState.softLoggedOut, LoginState.loggedOut]);
        loginStates.clear();

        await client.checkHomeserver(
          Uri.parse('https://fakeServer.notExisting'),
          checkWellKnown: false,
        );
        prepRefreshEndpoint(fakeApi);
        await client.login(
          LoginType.mLoginPassword,
          identifier: AuthenticationUserIdentifier(user: 'test'),
          password: '1234',
        );
        await client.abortSync();
        await client.refreshAccessToken();
        expect(client.accessToken, 'access_token_3');
        loginStates.clear();

        final loggedIn = client.onLoginStateChanged.stream.firstWhere(
          (state) => state == LoginState.loggedIn,
        );
        await client.ensureNotSoftLoggedOut();
        await loggedIn;
        expect(softLogouts, 3);
        expect(client.accessToken, 'access_token_4');

        await client.dispose();
      },
    );
  });
}
