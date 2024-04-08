class UserMediaConstraints {
  static const Map<String, Object> micMediaConstraints = {
    'echoCancellation': true,
    'noiseSuppression': true,
    'autoGainControl': false
  };

  static const Map<String, Object> camMediaConstraints = {
    'width': 1280,
    'height': 720,
    'facingMode': 'user',
  };

  static const Map<String, Object> screenMediaConstraints = {
    'audio': true,
    'video': true,
  };
}
