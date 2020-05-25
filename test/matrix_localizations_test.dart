/*
 * Copyright (c) 2019 Zender & Kurtz GbR.
 *
 * Authors:
 *   Christian Pauly <krille@famedly.com>
 *   Marcel Radzio <mtrnord@famedly.com>
 *
 * This file is part of famedlysdk.
 *
 * famedlysdk is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * famedlysdk is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with famedlysdk.  If not, see <http://www.gnu.org/licenses/>.
 */
import 'package:famedlysdk/famedlysdk.dart';
import 'package:test/test.dart';

import 'matrix_default_localizations.dart';

void main() {
  /// All Tests related to device keys
  group('Matrix Localizations', () {
    test('Matrix Localizations', () {
      expect(
          HistoryVisibility.invited
              .getLocalizedString(MatrixDefaultLocalizations()),
          'From the invitation');
      expect(
          HistoryVisibility.joined
              .getLocalizedString(MatrixDefaultLocalizations()),
          'From joining');
      expect(
          HistoryVisibility.shared
              .getLocalizedString(MatrixDefaultLocalizations()),
          'Visible for all participants');
      expect(
          HistoryVisibility.world_readable
              .getLocalizedString(MatrixDefaultLocalizations()),
          'Visible for everyone');
      expect(
          GuestAccess.can_join.getLocalizedString(MatrixDefaultLocalizations()),
          'Guests can join');
      expect(
          GuestAccess.forbidden
              .getLocalizedString(MatrixDefaultLocalizations()),
          'Guests are forbidden');
      expect(JoinRules.invite.getLocalizedString(MatrixDefaultLocalizations()),
          'Invited users only');
      expect(JoinRules.public.getLocalizedString(MatrixDefaultLocalizations()),
          'Anyone can join');
      expect(JoinRules.private.getLocalizedString(MatrixDefaultLocalizations()),
          'private');
      expect(JoinRules.knock.getLocalizedString(MatrixDefaultLocalizations()),
          'knock');
    });
  });
}
