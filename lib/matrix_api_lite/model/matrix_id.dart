const Set<String> matrixIdSigils = {'@', '!', '#', '\$', '+'};

const int matrixIdMaxLength = 255;

extension on String {
  String get _localpart => substring(1).split(':').first;
  String? get _domain {
    final colonIndex = indexOf(':');
    if (colonIndex == -1) return null;
    return substring(indexOf(':') + 1);
  }

  void _validate(String expectedSigil) {
    if (this != trim()) {
      throw Exception(
        'Invalid matrix id: String must not have leading or trailing whitespaces!',
      );
    }
    if (isEmpty) {
      throw Exception('Invalid matrix id: String is empty!');
    }

    // Check total length (including sigil and domain)
    if (length > matrixIdMaxLength) {
      throw Exception('Invalid matrix id: Must not exceed 255 bytes!');
    }

    // Validate localpart is not empty
    if (_localpart.isEmpty) {
      throw Exception('Invalid matrix id: Localpart must not be empty!');
    }

    // Validate localpart doesn't contain invalid characters
    if (_localpart.contains('\u0000')) {
      throw Exception(
        'Invalid matrix id: Localpart must not contain NUL character!',
      );
    }

    final sigil = this[0];

    if (sigil != expectedSigil) {
      throw Exception(
        'Invalid matrix id: Sigil was $sigil but expected $expectedSigil',
      );
    }

    if (!matrixIdSigils.contains(sigil)) {
      throw Exception('Invalid matrix id: Unknown sigil $sigil');
    }

    if ({'@', '#'}.contains(sigil) && _domain == null) {
      throw Exception(
        'Invalid matrix ID: Domain is required for User IDs and Room Aliases!',
      );
    }

    return; // Valid Matrix ID
  }
}

extension type UserId._(String string) {
  UserId(this.string) {
    string._validate(sigil);
  }

  UserId.from(String localpart, String domain) : string = '@$localpart:$domain';

  static const String sigil = '@';

  static UserId? tryParse(String string) {
    try {
      return UserId(string);
    } catch (_) {
      return null;
    }
  }

  String get localpart => string._localpart;
  String get domain => string._domain!;
}

extension type RoomId._(String matrixId) {
  RoomId(this.matrixId) {
    matrixId._validate(sigil);
  }

  RoomId.from(String localpart, [String? domain])
      : matrixId = '$sigil$localpart${domain == null ? '' : ':$domain'}';

  static const String sigil = '!';

  static RoomId? tryParse(String string) {
    try {
      return RoomId(string);
    } catch (_) {
      return null;
    }
  }

  String get localpart => matrixId._localpart;
  String? get domain => matrixId._domain;
}

extension type RoomAlias._(String matrixId) {
  RoomAlias(this.matrixId) {
    matrixId._validate(sigil);
  }

  RoomAlias.from(String localpart, String domain)
      : matrixId = '$sigil$localpart:$domain';

  static const String sigil = '#';

  static RoomAlias? tryParse(String string) {
    try {
      return RoomAlias(string);
    } catch (_) {
      return null;
    }
  }

  String get localpart => matrixId._localpart;
  String get domain => matrixId._domain!;
}

extension type EventId._(String matrixId) {
  EventId(this.matrixId) {
    matrixId._validate(sigil);
  }

  EventId.from(String localpart, [String? domain])
      : matrixId = '$sigil$localpart${domain == null ? '' : ':$domain'}';

  static const String sigil = '\$';

  static EventId? tryParse(String string) {
    try {
      return EventId(string);
    } catch (_) {
      return null;
    }
  }

  String get localpart => matrixId._localpart;
  String? get domain => matrixId._domain;
}
