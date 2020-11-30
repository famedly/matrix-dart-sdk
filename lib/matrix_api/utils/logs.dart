/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020 Famedly GmbH
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

import 'package:ansicolor/ansicolor.dart';

abstract class Logs {
  static final AnsiPen _infoPen = AnsiPen()..blue();
  static final AnsiPen _warningPen = AnsiPen()..yellow();
  static final AnsiPen _successPen = AnsiPen()..green();
  static final AnsiPen _errorPen = AnsiPen()..red();

  static const String _prefixText = '[Famedly Matrix SDK] ';

  // ignore: avoid_print
  static void info(dynamic info) => print(
        _prefixText + _infoPen(info.toString()),
      );

  // ignore: avoid_print
  static void success(dynamic obj, [dynamic stackTrace]) => print(
        _prefixText + _successPen(obj.toString()),
      );

  // ignore: avoid_print
  static void warning(dynamic warning, [dynamic stackTrace]) => print(
        _prefixText +
            _warningPen(warning.toString()) +
            (stackTrace != null ? '\n${stackTrace.toString()}' : ''),
      );

  // ignore: avoid_print
  static void error(dynamic obj, [dynamic stackTrace]) => print(
        _prefixText +
            _errorPen(obj.toString()) +
            (stackTrace != null ? '\n${stackTrace.toString()}' : ''),
      );
}
