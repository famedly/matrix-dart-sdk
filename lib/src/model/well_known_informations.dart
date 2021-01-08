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

class WellKnownInformations {
  MHomeserver mHomeserver;
  MHomeserver mIdentityServer;
  Map<String, dynamic> content;

  WellKnownInformations.fromJson(Map<String, dynamic> json) {
    content = json;
    mHomeserver = json['m.homeserver'] != null
        ? MHomeserver.fromJson(json['m.homeserver'])
        : null;
    mIdentityServer = json['m.identity_server'] != null
        ? MHomeserver.fromJson(json['m.identity_server'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final data = content;
    data['m.homeserver'] = mHomeserver.toJson();
    data['m.identity_server'] = mIdentityServer.toJson();
    return data;
  }
}

class MHomeserver {
  String baseUrl;

  MHomeserver.fromJson(Map<String, dynamic> json) {
    baseUrl = json['base_url'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['base_url'] = baseUrl;
    return data;
  }
}
