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

abstract class AuthenticationTypes {
  static const String password = 'm.login.password';
  static const String recaptcha = 'm.login.recaptcha';
  static const String token = 'm.login.token';
  static const String oauth2 = 'm.login.oauth2';
  static const String sso = 'm.login.sso';
  static const String emailIdentity = 'm.login.email.identity';
  static const String msisdn = 'm.login.msisdn';
  static const String dummy = 'm.login.dummy';
}

abstract class AuthenticationIdentifierTypes {
  static const String userId = 'm.id.user';
  static const String thirdParty = 'm.id.thirdparty';
  static const String phone = 'm.id.phone';
}
