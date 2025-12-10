import 'package:matrix/matrix.dart';

/// The StateStub is used in required_state to indicate that a piece of state has been deleted.
class StateStub extends BasicEvent {
  /// The state_key of the state entry that was deleted
  final String stateKey;

  StateStub({
    required super.type,
    required super.content,
    required this.stateKey,
  });

  StateStub.fromJson(super.json)
      : stateKey = json['state_key'] as String,
        super.fromJson();
}
