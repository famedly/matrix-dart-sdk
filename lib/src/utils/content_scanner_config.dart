// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Scanner endpoints used for Matrix media downloads.
class MatrixContentScannerConfig {
  /// Base URI for media downloads. `{serverName}/{mediaId}` is appended.
  final Uri downloadUri;

  /// Base URI for thumbnails. Thumbnail query parameters are preserved.
  final Uri downloadThumbnailUri;

  /// Full URI of the scanner's `download_encrypted` endpoint.
  final Uri downloadEncryptedUri;

  /// Whether scanner requests should include the Matrix access token.
  final bool withAuthHeader;

  /// Preview hint from scanner discovery. Stored for app-level decisions.
  final bool scanBeforePreview;

  MatrixContentScannerConfig({
    required Uri downloadUri,
    required Uri downloadThumbnailUri,
    required this.downloadEncryptedUri,
    this.withAuthHeader = true,
    this.scanBeforePreview = false,
  })  : downloadUri = _ensureTrailingSlash(downloadUri),
        downloadThumbnailUri = _ensureTrailingSlash(downloadThumbnailUri);

  factory MatrixContentScannerConfig.fromJson(Map<String, Object?> json) =>
      MatrixContentScannerConfig(
        downloadUri: Uri.parse(json['download_uri']! as String),
        downloadThumbnailUri:
            Uri.parse(json['download_thumbnail_uri']! as String),
        downloadEncryptedUri: Uri.parse(json['download_encrypted']! as String),
        withAuthHeader: (json['with_auth_header'] as bool?) ?? true,
        scanBeforePreview: (json['scan_before_preview'] as bool?) ?? false,
      );

  Map<String, Object?> toJson() => {
        'download_uri': downloadUri.toString(),
        'download_thumbnail_uri': downloadThumbnailUri.toString(),
        'download_encrypted': downloadEncryptedUri.toString(),
        'with_auth_header': withAuthHeader,
        'scan_before_preview': scanBeforePreview,
      };

  static Uri _ensureTrailingSlash(Uri uri) {
    if (uri.path.endsWith('/')) return uri;
    return uri.replace(path: '${uri.path}/');
  }
}

/// Thrown when the content scanner returns a non-2xx response.
class ContentScannerException implements Exception {
  /// Scanner error code, or `M_UNKNOWN` when the body cannot be parsed.
  final String reason;

  /// Human-readable scanner error.
  final String info;

  /// HTTP status code.
  final int statusCode;

  const ContentScannerException({
    required this.reason,
    required this.info,
    required this.statusCode,
  });

  static const reasonNotClean = 'MCS_MEDIA_NOT_CLEAN';
  static const reasonMimeTypeForbidden = 'MCS_MIME_TYPE_FORBIDDEN';
  static const reasonBadDecryption = 'MCS_BAD_DECRYPTION';
  static const reasonFailedToDecrypt = 'MCS_MEDIA_FAILED_TO_DECRYPT';
  static const reasonRequestFailed = 'MCS_MEDIA_REQUEST_FAILED';
  static const reasonUnknown = 'M_UNKNOWN';

  @override
  String toString() => 'ContentScannerException($statusCode $reason): $info';
}

/// Parses scanner and Matrix-style error responses.
ContentScannerException parseContentScannerError(http.Response response) {
  var reason = 'M_UNKNOWN';
  var info = response.reasonPhrase ?? response.body;
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, Object?>) {
      final r = decoded['reason'] ?? decoded['errcode'];
      final i = decoded['info'] ?? decoded['error'];
      if (r is String) reason = r;
      if (i is String) info = i;
    }
  } catch (_) {
    // Body is not JSON - keep defaults.
  }
  return ContentScannerException(
    reason: reason,
    info: info,
    statusCode: response.statusCode,
  );
}
