// SPDX-FileCopyrightText: 2019, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';
import 'package:test/test.dart';

void main() {
  /// All Tests related to device keys
  group('Matrix Localizations', () {
    test('Matrix Localizations', () {
      expect(
        HistoryVisibility.invited.getLocalizedString(
          MatrixDefaultLocalizations(),
        ),
        'From the invitation',
      );
      expect(
        HistoryVisibility.joined.getLocalizedString(
          MatrixDefaultLocalizations(),
        ),
        'From joining',
      );
      expect(
        HistoryVisibility.shared.getLocalizedString(
          MatrixDefaultLocalizations(),
        ),
        'Visible for all participants',
      );
      expect(
        HistoryVisibility.worldReadable.getLocalizedString(
          MatrixDefaultLocalizations(),
        ),
        'Visible for everyone',
      );
      expect(
        GuestAccess.canJoin.getLocalizedString(MatrixDefaultLocalizations()),
        'Guests can join',
      );
      expect(
        GuestAccess.forbidden.getLocalizedString(MatrixDefaultLocalizations()),
        'Guests are forbidden',
      );
      expect(
        JoinRules.invite.getLocalizedString(MatrixDefaultLocalizations()),
        'Invited users only',
      );
      expect(
        JoinRules.public.getLocalizedString(MatrixDefaultLocalizations()),
        'Anyone can join',
      );
      expect(
        JoinRules.private.getLocalizedString(MatrixDefaultLocalizations()),
        'private',
      );
      expect(
        JoinRules.knock.getLocalizedString(MatrixDefaultLocalizations()),
        'knock',
      );
    });
  });
}
