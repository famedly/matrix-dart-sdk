// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../matrix_api_lite.dart';

class SpaceChild {
  final String? roomId;
  final List<String> via;
  final String order;
  final bool? suggested;

  /// The validated room ID as a [RoomId], or null if unset or malformed.
  RoomId? get roomIdentifier =>
      roomId != null ? RoomId.tryParse(roomId!) : null;

  SpaceChild.fromState(StrippedStateEvent state)
    : assert(state.type == EventTypes.SpaceChild),
      roomId = state.stateKey,
      via = state.content.tryGetList<String>('via') ?? [],
      order = state.content.tryGet<String>('order') ?? '',
      suggested = state.content.tryGet<bool>('suggested');
}

class SpaceParent {
  final String? roomId;
  final List<String> via;
  final bool? canonical;

  /// The validated room ID as a [RoomId], or null if unset or malformed.
  RoomId? get roomIdentifier =>
      roomId != null ? RoomId.tryParse(roomId!) : null;

  SpaceParent.fromState(StrippedStateEvent state)
    : assert(state.type == EventTypes.SpaceParent),
      roomId = state.stateKey,
      via = state.content.tryGetList<String>('via') ?? [],
      canonical = state.content.tryGet<bool>('canonical');
}
