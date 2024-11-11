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

const Set<String> validSigils = {'@', '!', '#', '\$', '+'};

const int maxLength = 255;

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
    if (!validSigils.contains(substring(0, 1))) {
      return false;
    }
    // event IDs do not have to have a domain
    if (substring(0, 1) == '\$') {
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
