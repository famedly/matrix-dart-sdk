// SPDX-FileCopyrightText: 2019-2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:core';

import 'package:matrix/src/client.dart';

extension MxcUriExtension on Uri {
  /// Transforms this `mxc://` Uri into a `http` resource, which can be used
  /// to download the content.
  ///
  /// Throws an exception if the scheme is not `mxc` or the homeserver is not
  /// set.
  ///
  /// Important! To use this link you have to set a http header like this:
  /// `headers: {"authorization": "Bearer ${client.accessToken}"}`
  Future<Uri> getDownloadUri(Client client) async {
    String uriPath;

    if (await client.authenticatedMediaSupported()) {
      uriPath =
          '_matrix/client/v1/media/download/$host${hasPort ? ':$port' : ''}$path';
    } else {
      uriPath =
          '_matrix/media/v3/download/$host${hasPort ? ':$port' : ''}$path';
    }

    return isScheme('mxc')
        ? client.homeserver != null
            ? client.homeserver?.resolve(uriPath) ?? Uri()
            : Uri()
        : Uri();
  }

  /// Transforms this `mxc://` Uri into a `http` resource, which can be used
  /// to download the content with the given `width` and
  /// `height`. `method` can be `ThumbnailMethod.crop` or
  /// `ThumbnailMethod.scale` and defaults to `ThumbnailMethod.scale`.
  /// If `animated` (default false) is set to true, an animated thumbnail is requested
  /// as per MSC2705. Thumbnails only animate if the media repository supports that.
  ///
  /// Throws an exception if the scheme is not `mxc` or the homeserver is not
  /// set.
  ///
  /// Important! To use this link you have to set a http header like this:
  /// `headers: {"authorization": "Bearer ${client.accessToken}"}`
  Future<Uri> getThumbnailUri(
    Client client, {
    num? width,
    num? height,
    ThumbnailMethod? method = ThumbnailMethod.crop,
    bool? animated = false,
  }) async {
    if (!isScheme('mxc')) return Uri();
    final homeserver = client.homeserver;
    if (homeserver == null) {
      return Uri();
    }

    String requestPath;
    if (await client.authenticatedMediaSupported()) {
      requestPath =
          '/_matrix/client/v1/media/thumbnail/$host${hasPort ? ':$port' : ''}$path';
    } else {
      requestPath =
          '/_matrix/media/v3/thumbnail/$host${hasPort ? ':$port' : ''}$path';
    }

    return Uri(
      scheme: homeserver.scheme,
      host: homeserver.host,
      path: requestPath,
      port: homeserver.port,
      queryParameters: {
        if (width != null) 'width': width.round().toString(),
        if (height != null) 'height': height.round().toString(),
        if (method != null) 'method': method.toString().split('.').last,
        if (animated != null) 'animated': animated.toString(),
      },
    );
  }

  @Deprecated('Use `getDownloadUri()` instead')
  Uri getDownloadLink(Client matrix) => isScheme('mxc')
      ? matrix.homeserver != null
          ? matrix.homeserver?.resolve(
                '_matrix/media/v3/download/$host${hasPort ? ':$port' : ''}$path',
              ) ??
              Uri()
          : Uri()
      : Uri();

  /// Returns a scaled thumbnail link to this content with the given `width` and
  /// `height`. `method` can be `ThumbnailMethod.crop` or
  /// `ThumbnailMethod.scale` and defaults to `ThumbnailMethod.scale`.
  /// If `animated` (default false) is set to true, an animated thumbnail is requested
  /// as per MSC2705. Thumbnails only animate if the media repository supports that.
  @Deprecated('Use `getThumbnailUri()` instead')
  Uri getThumbnail(
    Client matrix, {
    num? width,
    num? height,
    ThumbnailMethod? method = ThumbnailMethod.crop,
    bool? animated = false,
  }) {
    if (!isScheme('mxc')) return Uri();
    final homeserver = matrix.homeserver;
    if (homeserver == null) {
      return Uri();
    }
    return Uri(
      scheme: homeserver.scheme,
      host: homeserver.host,
      path: '/_matrix/media/v3/thumbnail/$host${hasPort ? ':$port' : ''}$path',
      port: homeserver.port,
      queryParameters: {
        if (width != null) 'width': width.round().toString(),
        if (height != null) 'height': height.round().toString(),
        if (method != null) 'method': method.toString().split('.').last,
        if (animated != null) 'animated': animated.toString(),
      },
    );
  }
}

enum ThumbnailMethod { crop, scale }
