/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020 Famedly GmbH
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

import '../../famedlysdk.dart';

/// Wrapper to handle User interactive authentication requests
class UiaRequest<T> {
  void Function() onUpdate;
  void Function() onDone;
  final Future<T> Function(Map<String, dynamic> auth) request;
  String session;
  bool done = false;
  bool fail = false;
  T result;
  Exception error;
  Set<String> nextStages = <String>{};
  Map<String, dynamic> params = <String, dynamic>{};
  UiaRequest({this.onUpdate, this.request, this.onDone}) {
    run();
  }

  Future<T> run([Map<String, dynamic> auth]) async {
    try {
      auth ??= <String, dynamic>{};
      if (session != null) {
        auth['session'] = session;
      }
      final res = await request(auth);
      done = true;
      result = res;
      return res;
    } on MatrixException catch (err) {
      if (!(err.session is String)) {
        rethrow;
      }
      session ??= err.session;
      final completed = err.completedAuthenticationFlows ?? <String>[];
      final flows = err.authenticationFlows ?? <AuthenticationFlow>[];
      params = err.authenticationParams ?? <String, dynamic>{};
      nextStages = getNextStages(flows, completed);
      if (nextStages.isEmpty) {
        rethrow;
      }
      return null;
    } catch (err) {
      error = err is Exception ? err : Exception(err);
      fail = true;
      return null;
    } finally {
      if (onUpdate != null) {
        onUpdate();
      }
      if ((fail || done) && onDone != null) {
        onDone();
      }
    }
  }

  Future<T> completeStage(String type, [Map<String, dynamic> auth]) async {
    auth ??= <String, dynamic>{};
    auth['type'] = type;
    return await run(auth);
  }

  Set<String> getNextStages(
      List<AuthenticationFlow> flows, List<String> completed) {
    final nextStages = <String>{};
    for (final flow in flows) {
      final stages = flow.stages;
      final nextStage = stages[completed.length];
      if (nextStage != null) {
        var stagesValid = true;
        for (var i = 0; i < completed.length; i++) {
          if (stages[i] != completed[i]) {
            stagesValid = false;
            break;
          }
        }
        if (stagesValid) {
          nextStages.add(nextStage);
        }
      }
    }
    return nextStages;
  }
}
