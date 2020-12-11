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
