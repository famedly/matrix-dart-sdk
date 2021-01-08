import 'logs.dart';

extension TryGetMapExtension on Map<String, dynamic> {
  T tryGet<T>(String key, [T fallbackValue]) {
    final value = this[key];
    if (value != null && !(value is T)) {
      Logs().w(
          'Expected "${T.runtimeType}" in event content for the Key "$key" but got "${value.runtimeType}".');
      return fallbackValue;
    }
    if (value == null && fallbackValue != null) {
      Logs().w(
          'Required field in event content for the Key "$key" is null. Set to "$fallbackValue".');
      return fallbackValue;
    }
    return value;
  }

  List<T> tryGetList<T>(String key, [List<T> fallbackValue]) {
    final value = this[key];
    if (value != null && !(value is List)) {
      Logs().w(
          'Expected "${T.runtimeType}" in event content for the key "$key" but got "${value.runtimeType}".');
      return fallbackValue;
    }
    if (value == null && fallbackValue != null) {
      Logs().w(
          'Required field in event content for the key "$key" is null. Set to "$fallbackValue".');
      return fallbackValue;
    }
    try {
      return List<T>.from(value as List<dynamic>);
    } catch (_) {
      Logs().w(
          'Unable to create List<${T.runtimeType}> in event content for the key "$key');
      return fallbackValue;
    }
  }
}
