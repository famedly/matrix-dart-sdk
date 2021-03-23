// Copyright (c) 2020 Famedly GmbH
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:typed_data';

import 'subtle.dart';

Future<Uint8List> pbkdf2(Uint8List passphrase, Uint8List salt, int iterations, int bits) async {
  final raw = await importKey('raw', passphrase, 'PBKDF2', false, ['deriveBits']);
  final res = await deriveBits(Pbkdf2Params(name: 'PBKDF2', hash: 'SHA-512', salt: salt, iterations: iterations), raw, bits);
  return Uint8List.view(res);
}
