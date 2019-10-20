import 'package:famedlysdk/src/utils/ChatTime.dart';
import '../User.dart';

/// Represents a receipt.
/// This [user] has read an event at the given [time].
class Receipt {
  final User user;
  final ChatTime time;

  const Receipt(this.user, this.time);
}
