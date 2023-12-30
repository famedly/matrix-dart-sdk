import 'package:matrix/matrix.dart';
import 'package:matrix/src/voip/utils/types.dart';
import 'package:matrix/src/voip/utils/wrapped_media_stream.dart';

class GroupCallError extends Error {
  final String code;
  final String msg;
  final dynamic err;
  GroupCallError(this.code, this.msg, this.err);

  @override
  String toString() {
    return 'Group Call Error: [$code] $msg, err: ${err.toString()}';
  }
}

class GroupCallState {
  static String LocalCallFeedUninitialized = 'local_call_feed_uninitialized';
  static String InitializingLocalCallFeed = 'initializing_local_call_feed';
  static String LocalCallFeedInitialized = 'local_call_feed_initialized';
  static String Entering = 'entering';
  static String Entered = 'entered';
  static String Ended = 'ended';
}

abstract class ICallHandlers {
  Function(List<WrappedMediaStream> feeds)? onCallFeedsChanged;
  Function(CallState state, CallState oldState)? onCallStateChanged;
  Function(CallSession call)? onCallHangup;
  Function(CallSession newCall)? onCallReplaced;
}
