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

import 'package:http/http.dart' as http;

/// Represents a special response from the Homeserver for errors.
class ErrorResponse {

  /// The unique identifier for this error.
  String errcode;

  /// A human readable error description.
  String error;

  /// The frozen request which triggered this Error
  http.Request request;

  ErrorResponse({this.errcode, this.error, this.request});

  ErrorResponse.fromJson(Map<String, dynamic> json, http.Request newRequest) {
    errcode = json['errcode'];
    error = json['error'] ?? "";
    request = newRequest;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['errcode'] = this.errcode;
    data['error'] = this.error;
    return data;
  }
}
