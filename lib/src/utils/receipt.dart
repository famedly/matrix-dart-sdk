// @dart=2.9
/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020, 2021 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import '../user.dart';

/// Represents a receipt.
/// This [user] has read an event at the given [time].
class Receipt {
  final User user;
  final DateTime time;

  const Receipt(this.user, this.time);

  @override
  bool operator ==(dynamic other) => (other is Receipt &&
      other.user == user &&
      other.time.microsecondsSinceEpoch == time.microsecondsSinceEpoch);
}
