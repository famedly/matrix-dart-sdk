// SPDX-FileCopyrightText: 2019-Present, 2020, 2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

const Set<String> validSigils = {'@', '!', '#', '\$', '+'};

const int maxLength = 255;

/// Characters allowed in a *current* (post `v1.8`) user ID localpart:
/// `user_id_char = DIGIT / %x61-7A (a-z) / "-" / "." / "=" / "_" / "/" / "+"`.
///
/// Note that this intentionally rejects historical localparts (e.g. ones
/// containing uppercase letters), see [MatrixIdExtension.isValidMatrixIdStrict].
///
/// See: https://spec.matrix.org/v1.16/appendices/#user-identifiers
final RegExp _strictUserLocalpartRegExp = RegExp(r'^[0-9a-z\-.=_/+]+$');

/// A port: `port = 1*5DIGIT` (capped at the highest possible port number).
final RegExp _portRegExp = RegExp(r'^[0-9]{1,5}$');

/// A DNS name as `dns-name = 1*255dns-char` with
/// `dns-char = DIGIT / ALPHA / "-" / "."`. This also matches IPv4 literals,
/// which only use a subset of those characters.
final RegExp _dnsNameRegExp = RegExp(r'^[0-9A-Za-z\-.]{1,255}$');

/// An IPv6 literal as `IPv6address`. We do not fully validate the RFC 3513
/// grammar here, but restrict it to the allowed character set and length.
final RegExp _ipv6RegExp = RegExp(r'^[0-9A-Fa-f:.]{2,45}$');

/// Validates a `server_name` (`host [ ":" port ]`) against the Matrix
/// specification grammar.
///
/// See: https://spec.matrix.org/v1.16/appendices/#server-name
bool _isValidServerName(String serverName) {
  if (serverName.isEmpty) return false;

  // IPv6 literals are wrapped in brackets and may be followed by a port.
  if (serverName.startsWith('[')) {
    final closingBracket = serverName.indexOf(']');
    if (closingBracket == -1) return false;
    if (!_ipv6RegExp.hasMatch(serverName.substring(1, closingBracket))) {
      return false;
    }
    final rest = serverName.substring(closingBracket + 1);
    if (rest.isEmpty) return true;
    return rest.startsWith(':') && _portRegExp.hasMatch(rest.substring(1));
  }

  // DNS names and IPv4 literals never contain a colon, so the first colon
  // (if any) separates the optional port.
  var host = serverName;
  final colon = serverName.indexOf(':');
  if (colon != -1) {
    if (!_portRegExp.hasMatch(serverName.substring(colon + 1))) return false;
    host = serverName.substring(0, colon);
  }
  return _dnsNameRegExp.hasMatch(host);
}

extension MatrixIdExtension on String {
  List<String> _getParts() {
    final s = substring(1);
    final ix = s.indexOf(':');
    if (ix == -1) {
      return [substring(1)];
    }
    return [s.substring(0, ix), s.substring(ix + 1)];
  }

  bool get isValidMatrixId {
    if (isEmpty) return false;
    if (length > maxLength) return false;
    final sigil = substring(0, 1);
    if (!validSigils.contains(sigil)) {
      return false;
    }
    // event IDs and room IDs do not have to have a domain
    if ({'\$', '!'}.contains(sigil)) {
      return true;
    }
    // all other matrix IDs have to have a domain
    final parts = _getParts();
    // the localpart can be an empty string, e.g. for aliases
    if (parts.length != 2 || parts[1].isEmpty) {
      return false;
    }
    return true;
  }

  /// A stricter, spec-compliant version of [isValidMatrixId].
  ///
  /// [isValidMatrixId] is intentionally lenient: it only checks the sigil and
  /// the presence of a (non-empty) domain. This means malformed identifiers
  /// like `@@test:fakeServer.notExisting` or `@test:exa mple.com` pass it.
  ///
  /// This getter instead validates against the *current* Matrix identifier
  /// grammar:
  ///
  /// - the total length must not exceed 255 bytes,
  /// - user IDs (`@`) must have a localpart matching the current
  ///   `user_id_char` set (`[0-9a-z-.=_/+]`) and a valid `server_name`,
  /// - room aliases (`#`) and group IDs (`+`) must have a non-empty localpart
  ///   and a valid `server_name`,
  /// - room IDs (`!`) and event IDs (`$`) must have a non-empty opaque
  ///   localpart (their domain part, if present, is treated as opaque and not
  ///   validated, since event IDs since room version 3 do not carry one).
  ///
  /// Use this when validating identifiers you create or accept yourself (e.g.
  /// before registering an account or creating an alias) and you want them to
  /// conform to the current specification. Because it enforces the current
  /// grammar, it **rejects historical user IDs** (for example ones containing
  /// uppercase letters), which are still valid on the wire. For parsing or
  /// validating arbitrary identifiers received from a homeserver, keep using
  /// the lenient [isValidMatrixId] so legacy identifiers are not rejected.
  ///
  /// See: https://spec.matrix.org/v1.16/appendices/#identifier-grammar
  bool get isValidMatrixIdStrict {
    if (isEmpty) return false;
    // The spec length limit is expressed in bytes, not UTF-16 code units.
    if (utf8.encode(this).length > maxLength) return false;
    final sigil = substring(0, 1);
    if (!validSigils.contains(sigil)) return false;

    final parts = _getParts();
    final localpart = parts.first;
    final hasDomain = parts.length == 2;
    final domain = hasDomain ? parts[1] : null;

    switch (sigil) {
      case '@': // user id
        if (!hasDomain) return false;
        if (!_strictUserLocalpartRegExp.hasMatch(localpart)) return false;
        return _isValidServerName(domain!);
      case '#': // room alias
      case '+': // group id (deprecated)
        if (!hasDomain) return false;
        if (localpart.isEmpty || localpart.contains('\x00')) return false;
        return _isValidServerName(domain!);
      case '!': // room id
      case '\$': // event id (no domain since room version 3)
        if (localpart.isEmpty || localpart.contains('\x00')) return false;
        // A room id may carry an opaque ":domain" suffix. It must not be empty
        // if present, but is otherwise not parsed or validated.
        if (hasDomain && domain!.isEmpty) return false;
        return true;
      default:
        return false;
    }
  }

  String? get sigil => isValidMatrixId ? substring(0, 1) : null;

  String? get localpart => isValidMatrixId ? _getParts().first : null;

  String? get domain => isValidMatrixId ? _getParts().last : null;

  bool equals(String? other) => toLowerCase() == other?.toLowerCase();

  /// Parse a matrix identifier string into a Uri. Primary and secondary identifiers
  /// are stored in pathSegments. The query string is stored as such.
  Uri? _parseIdentifierIntoUri() {
    const matrixUriPrefix = 'matrix:';
    const matrixToPrefix = 'https://matrix.to/#/';
    if (toLowerCase().startsWith(matrixUriPrefix)) {
      final uri = Uri.tryParse(this);
      if (uri == null) return null;
      final pathSegments = uri.pathSegments;
      final identifiers = <String>[];
      for (var i = 0; i < pathSegments.length - 1; i += 2) {
        final thisSigil = {
          'u': '@',
          'roomid': '!',
          'r': '#',
          'e': '\$',
        }[pathSegments[i].toLowerCase()];
        if (thisSigil == null) {
          break;
        }
        identifiers.add(thisSigil + pathSegments[i + 1]);
      }
      return uri.replace(pathSegments: identifiers);
    } else if (toLowerCase().startsWith(matrixToPrefix)) {
      return Uri.tryParse(
        '//${substring(matrixToPrefix.length - 1).replaceAllMapped(RegExp(r'(?<=/)[#!@+][^:]*:|(\?.*$)'), (m) => m[0]!.replaceAllMapped(RegExp(m.group(1) != null ? '' : '[/?]'), (m) => Uri.encodeComponent(m.group(0)!))).replaceAll('#', '%23')}',
      );
    } else {
      return Uri(
        pathSegments: RegExp(r'/((?:[#!@+][^:]*:)?[^/?]*)(?:\?.*$)?')
            .allMatches('/$this')
            .map((m) => m[1]!),
        query: RegExp(r'(?:/(?:[#!@+][^:]*:)?[^/?]*)*\?(.*$)')
            .firstMatch('/$this')?[1],
      );
    }
  }

  /// Separate a matrix identifier string into a primary indentifier, a secondary identifier,
  /// a query string and already parsed `via` parameters. A matrix identifier string
  /// can be an mxid, a matrix.to-url or a matrix-uri.
  MatrixIdentifierStringExtensionResults? parseIdentifierIntoParts() {
    final uri = _parseIdentifierIntoUri();
    if (uri == null) return null;
    final primary = uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : null;
    if (primary == null || !primary.isValidMatrixId) return null;
    final secondary = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
    if (secondary != null && !secondary.isValidMatrixId) return null;

    return MatrixIdentifierStringExtensionResults(
      primaryIdentifier: primary,
      secondaryIdentifier: secondary,
      queryString: uri.query.isNotEmpty ? uri.query : null,
      via: (uri.queryParametersAll['via'] ?? []).toSet(),
      action: uri.queryParameters['action'],
    );
  }
}

class MatrixIdentifierStringExtensionResults {
  final String primaryIdentifier;
  final String? secondaryIdentifier;
  final String? queryString;
  final Set<String> via;
  final String? action;

  MatrixIdentifierStringExtensionResults({
    required this.primaryIdentifier,
    this.secondaryIdentifier,
    this.queryString,
    this.via = const {},
    this.action,
  });
}
