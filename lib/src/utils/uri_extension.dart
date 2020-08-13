/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020 Famedly GmbH
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

import 'dart:core';

import '../client.dart';

extension MxcUriExtension on Uri {
  /// Returns a download Link to this content.
  String getDownloadLink(Client matrix) => isScheme('mxc')
      ? matrix.homeserver != null
          ? '${matrix.homeserver.toString()}/_matrix/media/r0/download/$host$path'
          : ''
      : toString();

  /// Returns a scaled thumbnail link to this content with the given [width] and
  /// [height]. [method] can be [ThumbnailMethod.crop] or
  /// [ThumbnailMethod.scale] and defaults to [ThumbnailMethod.scale].
  String getThumbnail(Client matrix,
      {num width, num height, ThumbnailMethod method = ThumbnailMethod.crop}) {
    if (!isScheme('mxc')) return toString();
    final methodStr = method.toString().split('.').last;
    width = width.round();
    height = height.round();
    return matrix.homeserver != null
        ? '${matrix.homeserver.toString()}/_matrix/media/r0/thumbnail/$host$path?width=$width&height=$height&method=$methodStr'
        : '';
  }
}

enum ThumbnailMethod { crop, scale }
