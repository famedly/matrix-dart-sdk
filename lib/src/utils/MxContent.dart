import 'package:famedlysdk/src/Client.dart';
import 'dart:core';

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