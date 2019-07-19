/*
 * Copyright (c) 2019 Zender & Kurtz GbR.
 *
 * Authors:
 *   Christian Pauly <krille@famedly.com>
 *   Marcel Radzio <mtrnord@famedly.com>
 *
 * This file is part of famedlysdk.
 *
 * famedlysdk is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * famedlysdk is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with famedlysdk.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'package:famedlysdk/src/Client.dart';
import 'dart:core';

/// A file in Matrix presented by a mxc:// uri scheme.
class MxContent {
  final String _mxc;

  /// Insert a mxc:// uri here.
  MxContent(String mxcUrl) : this._mxc = mxcUrl ?? "";

  /// Returns the mxc uri.
  get mxc => _mxc;

  /// Returns a download Link to this content.
  String getDownloadLink(Client matrix) => matrix.homeserver != null
      ? "${matrix.homeserver}/_matrix/media/r0/download/${_mxc.replaceFirst("mxc://", "")}"
      : "";

  /// Returns a scaled thumbnail link to this content with the given [width] and
  /// [height]. [method] can be [ThumbnailMethod.crop] or
  /// [ThumbnailMethod.scale] and defaults to [ThumbnailMethod.scale].
  String getThumbnail(Client matrix,
      {num width, num height, ThumbnailMethod method}) {
    String methodStr = "crop";
    if (method == ThumbnailMethod.scale) methodStr = "scale";
    width = width.round();
    height = height.round();
    return matrix.homeserver != null
        ? "${matrix.homeserver}/_matrix/media/r0/thumbnail/${_mxc.replaceFirst("mxc://", "")}?width=$width&height=$height&method=$methodStr"
        : "";
  }
}

enum ThumbnailMethod { crop, scale }
