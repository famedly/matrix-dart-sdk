import 'package:ansicolor/ansicolor.dart';

abstract class Logs {
  static final AnsiPen _infoPen = AnsiPen()..blue();
  static final AnsiPen _warningPen = AnsiPen()..yellow();
  static final AnsiPen _successPen = AnsiPen()..green();
  static final AnsiPen _errorPen = AnsiPen()..red();

  static const String _prefixText = '[Famedly Matrix SDK] ';

  static void info(dynamic info) => print(
        _prefixText + _infoPen(info.toString()),
      );

  static void success(dynamic obj, [dynamic stackTrace]) => print(
        _prefixText + _successPen(obj.toString()),
      );

  static void warning(dynamic warning, [dynamic stackTrace]) => print(
        _prefixText +
            _warningPen(warning.toString()) +
            (stackTrace != null ? '\n${stackTrace.toString()}' : ''),
      );

  static void error(dynamic obj, [dynamic stackTrace]) => print(
        _prefixText +
            _errorPen(obj.toString()) +
            (stackTrace != null ? '\n${stackTrace.toString()}' : ''),
      );
}
