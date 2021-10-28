/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2021 Famedly GmbH
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

import '../../matrix.dart';

extension PushHelperClientExtension on Client {
  /// Set up a pusher: The optionally provided [pusher] is set up, removing old pushers
  /// and enabeling encrypted push, if available and [allowEncryption] is set to
  /// true (default). Additionally, optionally passed [oldTokens] are removed.
  /// If an [encryptedPusher] is set, then this one is used, if encryption is available.
  /// This allows to e.g. send full-event push notifications only on encrypted push.
  Future<void> setupPusher({
    Set<String>? oldTokens,
    Pusher? pusher,
    bool allowEncryption = true,
    Pusher? encryptedPusher,
  }) async {
    // first we test if the server supports encrypted push
    var haveEncryptedPush = false;
    if (pusher != null && encryptionEnabled && allowEncryption) {
      final versions = await getVersions();
      if (versions.unstableFeatures != null) {
        haveEncryptedPush =
            versions.unstableFeatures!['com.famedly.msc3013'] == true;
      }
    }
    // if the server *does* support encrypted push, we turn the pusher into an encrypted pusher
    final newPusher = haveEncryptedPush && pusher != null
        ? await encryption!.pushHelper.getPusher(encryptedPusher ?? pusher)
        : pusher;

    final pushers = await getPushers().catchError((e) {
      return <Pusher>[];
    });
    oldTokens ??= <String>{};
    var setNewPusher = false;
    if (newPusher != null) {
      // if we want to set a new pusher, we should look for if it already exists or needs updating
      final currentPushers =
          pushers?.where((p) => p.pushkey == newPusher.pushkey) ?? <Pusher>[];
      if (currentPushers.length == 1 &&
          currentPushers.first.kind == newPusher.kind &&
          currentPushers.first.appId == newPusher.appId &&
          currentPushers.first.appDisplayName == newPusher.appDisplayName &&
          currentPushers.first.lang == newPusher.lang &&
          currentPushers.first.data.url.toString() ==
              newPusher.data.url.toString() &&
          currentPushers.first.data.format == newPusher.data.format &&
          currentPushers.first.data.additionalProperties['algorithm'] ==
              newPusher.data.additionalProperties['algorithm'] &&
          currentPushers.first.data.additionalProperties['public_key'] ==
              newPusher.data.additionalProperties['public_key']) {
        Logs().i('[Push] Pusher already set');
      } else {
        Logs().i('[Push] Need to set new pusher');
        // there is an outdated version of this pusher, queue it for removal
        oldTokens.add(newPusher.pushkey);
        if (isLogged()) {
          setNewPusher = true;
        }
      }
    }
    // remove all old, outdated pushers
    for (final oldPusher in pushers ?? <Pusher>[]) {
      if ((newPusher != null &&
              oldPusher.pushkey != newPusher.pushkey &&
              oldPusher.appId == newPusher.appId) ||
          oldTokens.contains(oldPusher.pushkey)) {
        try {
          await deletePusher(oldPusher);
          Logs().i('[Push] Removed legacy pusher for this device');
        } catch (err) {
          Logs().w('[Push] Failed to remove old pusher', err);
        }
      }
    }
    // and finally set the new pusher
    if (setNewPusher && newPusher != null) {
      try {
        await postPusher(newPusher, append: false);
      } catch (e, s) {
        Logs().e('[Push] Unable to set pushers', e, s);
        rethrow;
      }
    }
  }

  /// Process a push payload, handeling encrypted push etc.
  Future<Map<String, dynamic>> processPushPayload(
      Map<String, dynamic> payload) async {
    final data = payload.tryGetMap<String, dynamic>('notification') ??
        payload.tryGetMap<String, dynamic>('data') ??
        payload;
    if (encryptionEnabled) {
      return await encryption!.pushHelper.processPushPayload(data);
    }
    return data;
  }
}
