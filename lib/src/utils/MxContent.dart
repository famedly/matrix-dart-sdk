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
 * along with Foobar.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'package:famedlysdk/src/Client.dart';
import 'dart:core';

/// A file in Matrix presented by a mxc:// uri scheme.
class MxContent {

  final String _mxc;

  MxContent(this._mxc);

  get mxc => _mxc;

  getDownloadLink (Client matrix) => "https://${matrix.homeserver}/_matrix/media/r0/download/${_mxc.replaceFirst("mxc://","")}/";

  getThumbnail (Client matrix, {num width, num height, ThumbnailMethod method}) {
    String methodStr = "crop";
    if (method == ThumbnailMethod.scale) methodStr = "scale";
    width = width.round();
    height = height.round();
    return "${matrix.homeserver}/_matrix/media/r0/thumbnail/${_mxc.replaceFirst("mxc://","")}?width=$width&height=$height&method=$methodStr";
  }

}

enum ThumbnailMethod {crop, scale}