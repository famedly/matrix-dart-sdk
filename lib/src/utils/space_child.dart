/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020, 2021 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:matrix/matrix_api_lite.dart';

class SpaceChild {
  final String? roomId;
  final List<String> via;
  final String order;
  final bool? suggested;

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

  SpaceParent.fromState(StrippedStateEvent state)
      : assert(state.type == EventTypes.SpaceParent),
        roomId = state.stateKey,
        via = state.content.tryGetList<String>('via') ?? [],
        canonical = state.content.tryGet<bool>('canonical');
}
