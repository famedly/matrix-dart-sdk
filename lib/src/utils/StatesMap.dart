import 'package:famedlysdk/famedlysdk.dart';

/// Matrix room states are addressed by a tuple of the [type] and an
/// optional [stateKey].
class StatesMap {
  Map<String, Map<String, RoomState>> states = {};

  /// Returns either the [RoomState] or a map of state_keys to [RoomState] objects.
  /// If you just enter a MatrixID, it will try to return the corresponding m.room.member event.
  dynamic operator [](String key) {
    if (key.startsWith("@") && key.contains(":")) {
      if (!states.containsKey("m.room.member")) states["m.room.member"] = {};
      return states["m.room.member"][key];
    }
    if (!states.containsKey(key)) states[key] = {};
    if (states[key][""] is RoomState)
      return states[key][""];
    else if (states[key].length == 0)
      return null;
    else
      return states[key];
  }

  void operator []=(String key, RoomState val) {
    if (key.startsWith("@") && key.contains(":")) {
      if (!states.containsKey("m.room.member")) states["m.room.member"] = {};
      states["m.room.member"][key] = val;
    }
    if (!states.containsKey(key)) states[key] = {};
    states[key][val.stateKey ?? ""] = val;
  }

  bool containsKey(String key) => states.containsKey(key);

  void forEach(f) => states.forEach(f);
}
