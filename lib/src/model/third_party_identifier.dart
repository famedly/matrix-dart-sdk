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

import '../matrix_api.dart';

class ThirdPartyIdentifier {
  ThirdPartyIdentifierMedium medium;
  String address;
  int validatedAt;
  int addedAt;

  ThirdPartyIdentifier.fromJson(Map<String, dynamic> json)
      : medium = ThirdPartyIdentifierMedium.values
            .firstWhere((medium) => describeEnum(medium) == json['medium']),
        address = json['address'],
        validatedAt = json['validated_at'],
        addedAt = json['added_at'];

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['medium'] = describeEnum(medium);
    data['address'] = address;
    data['validated_at'] = validatedAt;
    data['added_at'] = addedAt;
    return data;
  }
}
