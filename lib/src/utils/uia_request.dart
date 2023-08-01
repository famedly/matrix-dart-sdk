/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020, 2021 Famedly GmbH
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

import 'package:matrix/matrix.dart';

enum UiaRequestState {
  /// The request is done
  done,

  /// The request has failed
  fail,

  /// The request is currently loading
  loading,

  /// The request is waiting for user interaction
  waitForUser,
}

/// Wrapper to handle User interactive authentication requests
class UiaRequest<T> {
  void Function(UiaRequestState state)? onUpdate;
  final Future<T> Function(AuthenticationData? auth) request;
  String? session;
  UiaRequestState _state = UiaRequestState.loading;
  T? result;
  Exception? error;
  Set<String> nextStages = <String>{};
  Map<String, dynamic> params = <String, dynamic>{};

  UiaRequestState get state => _state;

  set state(UiaRequestState newState) {
    if (_state == newState) return;
    _state = newState;
    onUpdate?.call(newState);
  }

  UiaRequest({this.onUpdate, required this.request}) {
    _run();
  }

  Future<T?> _run([AuthenticationData? auth]) async {
    state = UiaRequestState.loading;
    try {
      final res = await request(auth);
      state = UiaRequestState.done;
      result = res;
      return res;
    } on MatrixException catch (err) {
      if (err.session == null) {
        error = err;
        state = UiaRequestState.fail;
        return null;
      }
      session ??= err.session;
      final completed = err.completedAuthenticationFlows;
      final flows = err.authenticationFlows ?? <AuthenticationFlow>[];
      params = err.authenticationParams ?? <String, dynamic>{};
      nextStages = getNextStages(flows, completed);
      if (nextStages.isEmpty) {
        error = err;
        state = UiaRequestState.fail;
        return null;
      }
      return null;
    } catch (err) {
      error = err is Exception ? err : Exception(err);
      state = UiaRequestState.fail;
      return null;
    } finally {
      if (state == UiaRequestState.loading) {
        state = UiaRequestState.waitForUser;
      }
    }
  }

  Future<T?> completeStage(AuthenticationData auth) => _run(auth);

  /// Cancel this uia request for example if the app can not handle this stage.
  void cancel([Exception? err]) {
    error = err ?? Exception('Request has been canceled');
    state = UiaRequestState.fail;
  }

  Set<String> getNextStages(
      List<AuthenticationFlow> flows, List<String> completed) {
    final nextStages = <String>{};
    for (final flow in flows) {
      // check the flow starts with the completed stages
      if (flow.stages.length >= completed.length &&
          flow.stages.take(completed.length).toSet().containsAll(completed)) {
        final stages = flow.stages.skip(completed.length);
        if (stages.isNotEmpty) nextStages.add(stages.first);
      }
    }
    return nextStages;
  }
}
