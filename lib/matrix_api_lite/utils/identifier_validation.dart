// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

/// Common basic validation for any Matrix identifier.
void validateCommonIdentifier(String value) {
  if (value.isEmpty) {
    throw const FormatException('Matrix identifier cannot be empty');
  }
  if (value.length > 255 || utf8.encode(value).length > 255) {
    throw FormatException('Identifier exceeds 255 UTF-8 bytes', value);
  }
  if (value.runes.any((rune) => rune == 0 || _isSurrogate(rune))) {
    throw FormatException(
      'Identifier contains NUL or an unpaired surrogate',
      value,
    );
  }
}

/// Grammar validation for room IDs, room aliases, and user IDs.
///
/// If [requireServerName] is false, allows domainless IDs (such as Room Version 12 IDs).
void validateIdentifier(
  String value, {
  required String sigil,
  bool requireServerName = true,
}) {
  if (!value.startsWith(sigil)) {
    throw FormatException('Expected identifier starting with $sigil', value);
  }
  final colonIndex = value.indexOf(':');
  if (colonIndex != -1) {
    final serverName = value.substring(colonIndex + 1);
    if (!_isValidServerName(serverName)) {
      throw FormatException('Invalid identifier server name', value);
    }
  } else if (requireServerName) {
    throw FormatException('Expected ${sigil}localpart:server_name', value);
  } else if (value.length <= 1) {
    throw FormatException('Identifier localpart is empty', value);
  }
}

/// Grammar validation for event IDs, supporting both historical ($localpart:server_name)
/// and modern room version 3+ opaque string/hash formats ($opaque_id).
///
/// Per the Matrix specification, clients treat modern event IDs as opaque strings
/// without imposing specific cryptographic hash format checks at the model layer.
void validateEventId(String value) {
  if (!value.startsWith(r'$')) {
    throw FormatException(r'Expected $event_id', value);
  }
  final colonIndex = value.indexOf(':');
  if (colonIndex != -1) {
    final serverName = value.substring(colonIndex + 1);
    if (!_isValidServerName(serverName)) {
      throw FormatException('Invalid identifier server name', value);
    }
  } else {
    if (value.length <= 1) {
      throw FormatException('Event ID localpart is empty', value);
    }
  }
}

/// Joins the sigil, localpart, and server name into a complete identifier.
String joinIdentifierParts(String sigil, String localpart, String serverName) {
  if (localpart.contains(':')) {
    throw FormatException('Identifier localpart must not contain :', localpart);
  }
  return '$sigil$localpart:$serverName';
}

bool _isSurrogate(int codePoint) => codePoint >= 0xD800 && codePoint <= 0xDFFF;

final _serverNamePattern = RegExp(
  r'^(?:\[([0-9A-Fa-f:.]{2,45})\]|([A-Za-z0-9.-]+))(?::[0-9]{1,5})?$',
);
final _digits = RegExp(r'^[0-9]+$');

bool _isValidServerName(String serverName) {
  final match = _serverNamePattern.firstMatch(serverName);
  if (match == null || match.end != serverName.length) return false;
  final ipv6 = match.group(1);
  if (ipv6 != null) {
    try {
      Uri.parseIPv6Address(ipv6);
      return true;
    } on FormatException {
      return false;
    }
  }
  final octets = match.group(2)!.split('.');
  if (octets.length == 4 && octets.every(_digits.hasMatch)) {
    return octets.every(
      (octet) => octet.length <= 3 && int.parse(octet) <= 255,
    );
  }
  return true;
}

/// Validation for a Matrix device ID.
///
/// Device IDs are opaque non-empty client-assigned or server-generated strings
/// without NUL or unpaired surrogates.
void validateDeviceId(String value) {
  if (value.isEmpty) {
    throw const FormatException('Device ID cannot be empty');
  }
  if (value.runes.any((rune) => rune == 0 || _isSurrogate(rune))) {
    throw FormatException(
      'Device ID contains NUL or an unpaired surrogate',
      value,
    );
  }
}
