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

abstract class ISendEventResponse {
  String? event_id;
}

class IGroupCallRoomMemberFeed {
  String? purpose;
  // TODO: Sources for adaptive bitrate
  IGroupCallRoomMemberFeed.fromJson(Map<String, dynamic> json) {
    purpose = json['purpose'];
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['purpose'] = purpose;
    return data;
  }
}

class IGroupCallRoomMemberDevice {
  String? device_id;
  String? session_id;
  int? expires_ts;

  List<IGroupCallRoomMemberFeed> feeds = [];
  IGroupCallRoomMemberDevice.fromJson(Map<String, dynamic> json) {
    device_id = json['device_id'];
    session_id = json['session_id'];
    expires_ts = json['expires_ts'];

    if (json['feeds'] != null) {
      feeds = (json['feeds'] as List<dynamic>)
          .map((feed) => IGroupCallRoomMemberFeed.fromJson(feed))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['device_id'] = device_id;
    data['session_id'] = session_id;
    data['expires_ts'] = expires_ts;
    data['feeds'] = feeds.map((feed) => feed.toJson()).toList();
    return data;
  }
}

class IGroupCallRoomMemberCallState {
  String? call_id;
  List<String>? foci;
  List<IGroupCallRoomMemberDevice> devices = [];
  IGroupCallRoomMemberCallState.fromJson(Map<String, dynamic> json) {
    call_id = json['m.call_id'];
    if (json['m.foci'] != null) {
      foci = (json['m.foci'] as List<dynamic>).cast<String>();
    }
    if (json['m.devices'] != null) {
      devices = (json['m.devices'] as List<dynamic>)
          .map((device) => IGroupCallRoomMemberDevice.fromJson(device))
          .toList();
    }
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['m.call_id'] = call_id;
    if (foci != null) {
      data['m.foci'] = foci;
    }
    if (devices.isNotEmpty) {
      data['m.devices'] = devices.map((e) => e.toJson()).toList();
    }
    return data;
  }
}

class IGroupCallRoomMemberState {
  List<IGroupCallRoomMemberCallState> calls = [];
  IGroupCallRoomMemberState.fromJson(MatrixEvent event) {
    if (event.content['m.calls'] != null) {
      for (final call in (event.content['m.calls'] as List<dynamic>)) {
        calls.add(IGroupCallRoomMemberCallState.fromJson(call));
      }
    }
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
