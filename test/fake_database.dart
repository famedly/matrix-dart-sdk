import 'package:famedlysdk/famedlysdk.dart';
import 'package:moor_ffi/moor_ffi.dart' as moor;

Database getDatabase() {
  return Database(moor.VmDatabase.memory());
}
