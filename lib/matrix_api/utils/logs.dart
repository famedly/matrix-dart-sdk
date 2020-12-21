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

import 'package:logger/logger.dart';

class Logs extends Logger {
  static final Logs _singleton = Logs._internal();

  factory Logs() {
    return _singleton;
  }

  set level(Level newLevel) => Logger.level = newLevel;

  final List<OutputEvent> outputEvents = [];

  Logs._internal()
      : super(
          printer: PrettyPrinter(methodCount: 0, lineLength: 100),
          filter: _MatrixSdkFilter(),
          output: _CacheOutput(),
        );
}

class _MatrixSdkFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) => event.level.index >= Logger.level.index;
}

class _CacheOutput extends ConsoleOutput {
  @override
  void output(OutputEvent event) {
    Logs().outputEvents.add(event);
    super.output(event);
  }
}
