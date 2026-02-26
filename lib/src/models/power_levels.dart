/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2026 Famedly GmbH
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

abstract class PowerLevels {
  static const int user = 0;
  static const int moderator = 50;
  static const int admin = 100;

  // 2^53 - 1 from https://spec.matrix.org/v1.15/appendices/#canonical-json
  static const int owner = 9007199254740991;

  static bool isUser(int level) => level < 50;
  static bool isModerator(int level) => level >= 50 && level < 100;
  static bool isAdmin(int level) => level >= 100 && level < owner;
  static bool isOwner(int level) => level == owner;
}
