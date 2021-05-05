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

import '../utils/map_copy_extension.dart';

class OneTimeKeysClaimResponse {
  Map<String, dynamic> failures;
  Map<String, Map<String, dynamic>> oneTimeKeys;

  OneTimeKeysClaimResponse.fromJson(Map<String, dynamic> json)
      : failures = (json['failures'] as Map<String, dynamic>)?.copy() ?? {},
        // We still need a Map<...>.from(...) to ensure all second-level entries are also maps
        oneTimeKeys = Map<String, Map<String, dynamic>>.from(
            (json['one_time_keys'] as Map<String, dynamic>).copy());

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (failures != null) {
      data['failures'] = failures;
    }
    if (oneTimeKeys != null) {
      data['one_time_keys'] = oneTimeKeys;
    }
    return data;
  }
}
