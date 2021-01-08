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
          'Expected "List<${T.runtimeType}>" in event content for the key "$key" but got "${value.runtimeType}".');
      return fallbackValue;
    }
    if (value == null && fallbackValue != null) {
      Logs().w(
          'Required field in event content for the key "$key" is null. Set to "$fallbackValue".');
      return fallbackValue;
    }
    try {
      return List<T>.from(value);
    } catch (_) {
      Logs().w(
          'Unable to create "List<${T.runtimeType}>" in event content for the key "$key"');
      return fallbackValue;
    }
  }

  Map<A, B> tryGetMap<A, B>(String key, [Map<A, B> fallbackValue]) {
    final value = this[key];
    if (value != null && !(value is Map)) {
      Logs().w(
          'Expected "Map<${A.runtimeType},${B.runtimeType}>" in event content for the key "$key" but got "${value.runtimeType}".');
      return fallbackValue;
    }
    if (value == null && fallbackValue != null) {
      Logs().w(
          'Required field in event content for the key "$key" is null. Set to "$fallbackValue".');
      return fallbackValue;
    }
    try {
      return Map<A, B>.from(value);
    } catch (_) {
      Logs().w(
          'Unable to create "Map<${A.runtimeType},${B.runtimeType}>" in event content for the key "$key"');
      return fallbackValue;
    }
  }
}
