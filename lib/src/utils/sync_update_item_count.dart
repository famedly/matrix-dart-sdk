import 'package:matrix/matrix.dart';

extension SyncUpdateItemCount on SyncUpdate {
  int get itemCount {
    var count = 0;
    count += accountData?.length ?? 0;
    count += deviceLists?.changed?.length ?? 0;
    count += deviceLists?.left?.length ?? 0;
    count += toDevice?.length ?? 0;
    count += presence?.length ?? 0;
    count += _joinRoomsItemCount;
    count += _inviteRoomsItemCount;
    count += _leaveRoomsItemCount;
    return count;
  }

  int get _joinRoomsItemCount =>
      rooms?.join?.values.fold<int>(
        0,
        (prev, room) =>
            prev +
            (room.accountData?.length ?? 0) +
            (room.state?.length ?? 0) +
            (room.timeline?.events?.length ?? 0),
      ) ??
      0;

  int get _inviteRoomsItemCount =>
      rooms?.invite?.values.fold<int>(
        0,
        (prev, room) => prev + (room.inviteState?.length ?? 0),
      ) ??
      0;

  int get _leaveRoomsItemCount =>
      rooms?.leave?.values.fold<int>(
        0,
        (prev, room) =>
            prev +
            (room.accountData?.length ?? 0) +
            (room.state?.length ?? 0) +
            (room.timeline?.events?.length ?? 0),
      ) ??
      0;
}
