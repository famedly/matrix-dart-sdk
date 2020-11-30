import 'logs.dart';

extension TryGetMapExtension on Map<String, dynamic> {
  T tryGet<T>(String key, [T fallbackValue]) {
    final value = this[key];
    if (value != null && !(value is T)) {
      Logs.warning(
          'Expected "${T.runtimeType}" in event content for the Key "$key" but got "${value.runtimeType}".');
      return fallbackValue;
    }
    if (value == null && fallbackValue != null) {
      Logs.warning(
          'Required field in event content for the Key "$key" is null. Set to "$fallbackValue".');
      return fallbackValue;
    }
    return value;
  }
}
