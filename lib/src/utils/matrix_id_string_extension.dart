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
    if (isEmpty ?? true) return false;
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

  String get sigil => isValidMatrixId ? substring(0, 1) : null;

  String get localpart => isValidMatrixId ? _getParts().first : null;

  String get domain => isValidMatrixId ? _getParts().last : null;

  bool equals(String other) => toLowerCase() == other?.toLowerCase();

  /// Separate a matrix identifier string into a primary indentifier, a secondary identifier,
  /// a query string and already parsed `via` parameters. A matrix identifier string
  /// can be an mxid, a matrix.to-url or a matrix-uri.
  MatrixIdentifierStringExtensionResults parseIdentifierIntoParts() {
    const matrixUriPrefix = 'matrix:';

    // check if we have a "matrix:" uri
    if (toLowerCase().startsWith(matrixUriPrefix)) {
      final uri = Uri.tryParse(this);
      if (uri == null) {
        return null;
      }
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
        final identifier = thisSigil + pathSegments[i + 1];
        if (!identifier.isValidMatrixId) {
          return null;
        }
        identifiers.add(identifier);
      }
      if (identifiers.isEmpty) {
        return null;
      }
      return MatrixIdentifierStringExtensionResults(
        primaryIdentifier: identifiers.first,
        secondaryIdentifier: identifiers.length > 1 ? identifiers[1] : null,
        queryString: uri.query.isNotEmpty ? uri.query : null,
        via: (uri.queryParametersAll['via'] ?? []).toSet(),
        action: uri.queryParameters['action'],
      );
    }

    const matrixToPrefix = 'https://matrix.to/#/';
    // matrix identifiers and matrix.to URLs are parsed similarly, so we do them here
    var s = this;
    if (toLowerCase().startsWith(matrixToPrefix)) {
      // as we decode a component we may only call it on the url part *before* the "query" part
      final parts = substring(matrixToPrefix.length).split('?');
      var ident = parts.removeAt(0);
      try {
        ident = Uri.decodeComponent(ident);
      } catch (_) {
        // do nothing: the identifier wasn't url-encoded, and we already have the
        // plaintext version in the `ident` variable
      }
      s = ident + '?' + parts.join('?');
    }
    final match = RegExp(r'^([#!@+][^:]*:[^\/?]*)(?:\/(\$[^?]*))?(?:\?(.*))?$')
        .firstMatch(s);
    if (match == null ||
        !match.group(1).isValidMatrixId ||
        !(match.group(2)?.isValidMatrixId ?? true)) {
      return null;
    }
    final uri = Uri(query: match.group(3));
    return MatrixIdentifierStringExtensionResults(
      primaryIdentifier: match.group(1),
      secondaryIdentifier: match.group(2),
      queryString: uri.query.isNotEmpty ? uri.query : null,
      via: (uri.queryParametersAll['via'] ?? []).toSet(),
      action: uri.queryParameters['action'],
    );
  }
}

class MatrixIdentifierStringExtensionResults {
  final String primaryIdentifier;
  final String secondaryIdentifier;
  final String queryString;
  final Set<String> via;
  final String action;

  MatrixIdentifierStringExtensionResults(
      {this.primaryIdentifier,
      this.secondaryIdentifier,
      this.queryString,
      this.via,
      this.action});
}
