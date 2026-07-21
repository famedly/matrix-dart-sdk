// SPDX-FileCopyrightText: 2019-Present, 2020, 2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

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
    // ignore: discarded_futures
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
    List<AuthenticationFlow> flows,
    List<String> completed,
  ) {
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
