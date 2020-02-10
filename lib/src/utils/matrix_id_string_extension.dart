extension MatrixIdExtension on String {
  static const Set<String> VALID_SIGILS = {"@", "!", "#", "\$", "+"};

  static const int MAX_LENGTH = 255;

  bool get isValidMatrixId {
    if (this.length > MAX_LENGTH) return false;
    if (!VALID_SIGILS.contains(this.substring(0, 1))) {
      return false;
    }
    final List<String> parts = this.substring(1).split(":");
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      return false;
    }
    return true;
  }

  String get sigil => isValidMatrixId ? this.substring(0, 1) : null;

  String get localpart =>
      isValidMatrixId ? this.substring(1).split(":").first : null;

  String get domain => isValidMatrixId ? this.substring(1).split(":")[1] : null;

  bool equals(String other) => this.toLowerCase() == other.toLowerCase();
}
