/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020 Famedly GmbH
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

abstract class AlgorithmTypes {
  static const String olmV1Curve25519AesSha2 = 'm.olm.v1.curve25519-aes-sha2';
  static const String megolmV1AesSha2 = 'm.megolm.v1.aes-sha2';
  static const String secretStorageV1AesHmcSha2 =
      'm.secret_storage.v1.aes-hmac-sha2';
  static const String megolmBackupV1Curve25519AesSha2 =
      'm.megolm_backup.v1.curve25519-aes-sha2';
  static const String pbkdf2 = 'm.pbkdf2';
}
