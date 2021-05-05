/* MIT License
* 
* Copyright (C) 2019, 2020, 2021 Famedly GmbH
* 
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
* 
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
* 
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

class OpenGraphData {
  String ogTitle;
  String ogDescription;
  String ogImage;
  String ogImageType;
  int ogImageHeight;
  int ogImageWidth;
  int matrixImageSize;

  OpenGraphData.fromJson(Map<String, dynamic> json)
      : ogTitle = json['og:title'],
        ogDescription = json['og:description'],
        ogImage = json['og:image'],
        ogImageType = json['og:image:type'],
        ogImageHeight = json['og:image:height'],
        ogImageWidth = json['og:image:width'],
        matrixImageSize = json['matrix:image:size'];

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
