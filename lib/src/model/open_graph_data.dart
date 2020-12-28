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

class OpenGraphData {
  String ogTitle;
  String ogDescription;
  String ogImage;
  String ogImageType;
  int ogImageHeight;
  int ogImageWidth;
  int matrixImageSize;

  OpenGraphData.fromJson(Map<String, dynamic> json) {
    ogTitle = json['og:title'];
    ogDescription = json['og:description'];
    ogImage = json['og:image'];
    ogImageType = json['og:image:type'];
    ogImageHeight = json['og:image:height'];
    ogImageWidth = json['og:image:width'];
    matrixImageSize = json['matrix:image:size'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (ogTitle != null) {
      data['og:title'] = ogTitle;
    }
    if (ogDescription != null) {
      data['og:description'] = ogDescription;
    }
    if (ogImage != null) {
      data['og:image'] = ogImage;
    }
    if (ogImageType != null) {
      data['og:image:type'] = ogImageType;
    }
    if (ogImageHeight != null) {
      data['og:image:height'] = ogImageHeight;
    }
    if (ogImageWidth != null) {
      data['og:image:width'] = ogImageWidth;
    }
    if (matrixImageSize != null) {
      data['matrix:image:size'] = matrixImageSize;
    }
    return data;
  }
}
