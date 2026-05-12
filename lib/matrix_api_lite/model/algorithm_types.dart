// SPDX-FileCopyrightText: 2019-2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

abstract class AlgorithmTypes {
  static const String olmV1Curve25519AesSha2 = 'm.olm.v1.curve25519-aes-sha2';
  static const String megolmV1AesSha2 = 'm.megolm.v1.aes-sha2';
  static const String secretStorageV1AesHmcSha2 =
      'm.secret_storage.v1.aes-hmac-sha2';
  static const String megolmBackupV1Curve25519AesSha2 =
      'm.megolm_backup.v1.curve25519-aes-sha2';
  static const String pbkdf2 = 'm.pbkdf2';
}
