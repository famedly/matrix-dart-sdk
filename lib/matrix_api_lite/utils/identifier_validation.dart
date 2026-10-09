// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

final _serverNamePattern = RegExp(
  r'^(?:\[([0-9A-Fa-f:.]{2,45})\]|([A-Za-z0-9.-]+))(?::[0-9]{1,5})?$',
);
final _digits = RegExp(r'^[0-9]+$');

/// Validates whether [serverName] conforms to the Matrix server name specification
/// (domain, IPv4, or bracketed IPv6 with optional port).
bool isValidServerName(String serverName) {
  if (serverName.isEmpty) return false;
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
  final host = match.group(2);
  if (host != null) {
    final octets = host.split('.');
    if (octets.length == 4 && octets.every(_digits.hasMatch)) {
      return octets.every(
        (octet) => octet.length <= 3 && int.parse(octet) <= 255,
      );
    }
  }
  return true;
}

bool _isValidCommonIdentifier(String value) {
  if (value.isEmpty || value.length > 255) return false;
  for (final rune in value.runes) {
    if (rune == 0 || (rune >= 0xD800 && rune <= 0xDFFF)) {
      return false;
    }
  }
  return utf8.encode(value).length <= 255;
}

/// Checks if [value] is non-empty, <= 255 UTF-8 bytes, and contains no NUL or unpaired surrogates.
bool isValidCommonIdentifier(String value) => _isValidCommonIdentifier(value);

/// Checks if [value] is a valid Matrix user ID (`@localpart:server_name`).
bool isValidUserId(String value) {
  if (!isValidCommonIdentifier(value)) return false;
  if (!value.startsWith('@')) return false;
  final colonIndex = value.indexOf(':');
  if (colonIndex == -1) return false;
  final serverName = value.substring(colonIndex + 1);
  return isValidServerName(serverName);
}

/// Checks if [value] is a valid Matrix room ID (`!localpart:server_name` or room v12 domainless `!opaque_id`).
bool isValidRoomId(String value) {
  if (!isValidCommonIdentifier(value)) return false;
  if (!value.startsWith('!')) return false;
  final colonIndex = value.indexOf(':');
  if (colonIndex != -1) {
    final serverName = value.substring(colonIndex + 1);
    return isValidServerName(serverName);
  }
  return value.length > 1;
}

/// Checks if [value] is a valid Matrix room alias (`#localpart:server_name`).
bool isValidRoomAlias(String value) {
  if (!isValidCommonIdentifier(value)) return false;
  if (!value.startsWith('#')) return false;
  final colonIndex = value.indexOf(':');
  if (colonIndex == -1) return false;
  final serverName = value.substring(colonIndex + 1);
  return isValidServerName(serverName);
}

/// Checks if [value] is a valid Matrix event ID (`$opaque_id` or historical `$localpart:server_name`).
bool isValidEventId(String value) {
  if (!isValidCommonIdentifier(value)) return false;
  if (!value.startsWith(r'$')) return false;
  final colonIndex = value.indexOf(':');
  if (colonIndex != -1) {
    final serverName = value.substring(colonIndex + 1);
    return isValidServerName(serverName);
  }
  return value.length > 1;
}

/// Checks if [value] is a valid Matrix device ID.
bool isValidDeviceId(String value) => _isValidCommonIdentifier(value);
