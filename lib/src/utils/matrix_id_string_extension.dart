// SPDX-FileCopyrightText: 2019-Present, 2020, 2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

const Set<String> validSigils = {'@', '!', '#', '\$', '+'};

const int maxLength = 255;

// Spec grammar for user ID localparts (since v1.8). Excludes legacy ids.
final RegExp _strictUserLocalpartRegExp = RegExp(r'^[0-9a-z\-.=_/+]+$');

// server_name = hostname [ ":" port ]
final RegExp _portRegExp = RegExp(r'^[0-9]{1,5}$');
final RegExp _dnsNameRegExp = RegExp(r'^[0-9A-Za-z\-.]{1,255}$');
final RegExp _ipv6RegExp = RegExp(r'^[0-9A-Fa-f:.]{2,45}$');

bool _isValidServerName(String serverName) {
  if (serverName.isEmpty) return false;

  // IPv6 literal in brackets, optionally followed by a port.
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

  // DNS name / IPv4 don't contain a colon, so any colon separates the port.
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

  @Deprecated('Use isValidMatrixIdStrict() instead')
  bool get isValidMatrixId => isValidMatrixIdStrict();

  /// Whether this is a valid matrix id (user, room, alias, event or group).
  ///
  /// Lenient by default. Pass [allowHistoricalUserIds] as `false` to enforce
  /// the spec user id localpart charset and [strictDomainCheck] as `true` to
  /// validate the domain (dns/ipv4/ipv6/port).
  ///
  /// See: https://spec.matrix.org/v1.16/appendices/#identifier-grammar
  bool isValidMatrixIdStrict({
    bool allowHistoricalUserIds = true,
    bool strictDomainCheck = false,
  }) {
    if (isEmpty) return false;
    if (length > maxLength) return false;
    final sigil = substring(0, 1);
    if (!validSigils.contains(sigil)) return false;

    final parts = _getParts();
    final localpart = parts.first;
    final hasDomain = parts.length == 2;
    final domain = hasDomain ? parts[1] : null;

    switch (sigil) {
      case '!': // room id
      case '\$': // event id, domain optional
        if (hasDomain && strictDomainCheck) return _isValidServerName(domain!);
        return true;
      case '@': // user id
      case '#': // room alias
      case '+': // group
        if (!hasDomain || domain!.isEmpty) return false;
        if (sigil == '@' &&
            !allowHistoricalUserIds &&
            !_strictUserLocalpartRegExp.hasMatch(localpart)) {
          return false;
        }
        if (strictDomainCheck && !_isValidServerName(domain)) return false;
        return true;
      default:
        return false;
    }
  }

  String? get sigil => isValidMatrixIdStrict() ? substring(0, 1) : null;

  String? get localpart => isValidMatrixIdStrict() ? _getParts().first : null;

  String? get domain => isValidMatrixIdStrict() ? _getParts().last : null;

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
        pathSegments: RegExp(
          r'/((?:[#!@+][^:]*:)?[^/?]*)(?:\?.*$)?',
        ).allMatches('/$this').map((m) => m[1]!),
        query: RegExp(
          r'(?:/(?:[#!@+][^:]*:)?[^/?]*)*\?(.*$)',
        ).firstMatch('/$this')?[1],
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
    if (primary == null || !primary.isValidMatrixIdStrict()) return null;
    final secondary = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
    if (secondary != null && !secondary.isValidMatrixIdStrict()) return null;

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
