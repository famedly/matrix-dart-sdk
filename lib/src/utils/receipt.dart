import '../user.dart';

/// Represents a receipt.
/// This [user] has read an event at the given [time].
class Receipt {
  final User user;
  final DateTime time;

  const Receipt(this.user, this.time);

  @override
  bool operator ==(dynamic other) => (other is Receipt &&
      other.user == user &&
      other.time.microsecondsSinceEpoch == time.microsecondsSinceEpoch);
}
