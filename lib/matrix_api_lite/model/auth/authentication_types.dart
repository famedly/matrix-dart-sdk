// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

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
