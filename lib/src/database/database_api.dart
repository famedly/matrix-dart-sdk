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

import 'dart:typed_data';

import 'package:matrix/encryption/utils/olm_session.dart';
import 'package:matrix/encryption/utils/outbound_group_session.dart';
import 'package:matrix/encryption/utils/ssss_cache.dart';
import 'package:matrix/encryption/utils/stored_inbound_group_session.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/queued_to_device_event.dart';

abstract class DatabaseApi {
  int get maxFileSize => 1 * 1024 * 1024;
  bool get supportsFileStoring => false;
  Future<Map<String, dynamic>?> getClient(String name);

  Future updateClient(
    String homeserverUrl,
    String token,
    String? refreshToken,
    String userId,
    String? deviceId,
    String? deviceName,
    String? prevBatch,
    String? olmAccount,
  );

  Future insertClient(
    String name,
    String homeserverUrl,
    String token,
    String? refreshToken,
    String userId,
    String? deviceId,
    String? deviceName,
    String? prevBatch,
    String? olmAccount,
  );

  Future<List<Room>> getRoomList(Client client);

  Future<Room?> getSingleRoom(Client client, String roomId,
      {bool loadImportantStates = true});

  Future<Map<String, BasicEvent>> getAccountData();

  /// Stores a RoomUpdate object in the database. Must be called inside of
  /// [transaction].
  Future<void> storeRoomUpdate(
      String roomId, SyncRoomUpdate roomUpdate, Client client);

  /// Stores an EventUpdate object in the database. Must be called inside of
  /// [transaction].
  Future<void> storeEventUpdate(EventUpdate eventUpdate, Client client);

  Future<Event?> getEventById(String eventId, Room room);

  Future<void> forgetRoom(String roomId);

  Future<void> clearCache();

  Future<void> clear();

  Future<User?> getUser(String userId, Room room);

  Future<List<User>> getUsers(Room room);

  Future<List<Event>> getEventList(
    Room room, {
    int start = 0,
    bool onlySending = false,
    int? limit,
  });

  Future<List<String>> getEventIdList(
    Room room, {
    int start = 0,
    bool includeSending = false,
    int? limit,
  });

  Future<Uint8List?> getFile(Uri mxcUri);

  Future storeFile(Uri mxcUri, Uint8List bytes, int time);

  Future storeSyncFilterId(
    String syncFilterId,
  );

  Future storeAccountData(String type, String content);

  Future<Map<String, DeviceKeysList>> getUserDeviceKeys(Client client);

  Future<SSSSCache?> getSSSSCache(String type);

  Future<OutboundGroupSession?> getOutboundGroupSession(
    String roomId,
    String userId,
  );

  Future<List<StoredInboundGroupSession>> getAllInboundGroupSessions();

  Future<StoredInboundGroupSession?> getInboundGroupSession(
    String roomId,
    String sessionId,
  );

  Future updateInboundGroupSessionIndexes(
    String indexes,
    String roomId,
    String sessionId,
  );

  Future storeInboundGroupSession(
    String roomId,
    String sessionId,
    String pickle,
    String content,
    String indexes,
    String allowedAtIndex,
    String senderKey,
    String senderClaimedKey,
  );

  Future markInboundGroupSessionAsUploaded(
    String roomId,
    String sessionId,
  );

  Future updateInboundGroupSessionAllowedAtIndex(
    String allowedAtIndex,
    String roomId,
    String sessionId,
  );

  Future removeOutboundGroupSession(String roomId);

  Future storeOutboundGroupSession(
    String roomId,
    String pickle,
    String deviceIds,
    int creationTime,
  );

  Future updateClientKeys(
    String olmAccount,
  );

  Future storeOlmSession(
    String identityKey,
    String sessionId,
    String pickle,
    int lastReceived,
  );

  Future setLastActiveUserDeviceKey(
    int lastActive,
    String userId,
    String deviceId,
  );

  Future setLastSentMessageUserDeviceKey(
    String lastSentMessage,
    String userId,
    String deviceId,
  );

  Future clearSSSSCache();

  Future storeSSSSCache(
    String type,
    String keyId,
    String ciphertext,
    String content,
  );

  Future markInboundGroupSessionsAsNeedingUpload();

  Future storePrevBatch(
    String prevBatch,
  );

  Future deleteOldFiles(int savedAt);

  Future storeUserDeviceKeysInfo(
    String userId,
    bool outdated,
  );

  Future storeUserDeviceKey(
    String userId,
    String deviceId,
    String content,
    bool verified,
    bool blocked,
    int lastActive,
  );

  Future removeUserDeviceKey(
    String userId,
    String deviceId,
  );

  Future removeUserCrossSigningKey(
    String userId,
    String publicKey,
  );

  Future storeUserCrossSigningKey(
    String userId,
    String publicKey,
    String content,
    bool verified,
    bool blocked,
  );

  Future deleteFromToDeviceQueue(int id);

  Future removeEvent(String eventId, String roomId);

  Future setRoomPrevBatch(
    String? prevBatch,
    String roomId,
    Client client,
  );

  Future setVerifiedUserCrossSigningKey(
    bool verified,
    String userId,
    String publicKey,
  );

  Future setBlockedUserCrossSigningKey(
    bool blocked,
    String userId,
    String publicKey,
  );

  Future setVerifiedUserDeviceKey(
    bool verified,
    String userId,
    String deviceId,
  );

  Future setBlockedUserDeviceKey(
    bool blocked,
    String userId,
    String deviceId,
  );

  Future<List<Event>> getUnimportantRoomEventStatesForRoom(
    List<String> events,
    Room room,
  );

  Future<List<OlmSession>> getOlmSessions(
    String identityKey,
    String userId,
  );

  Future<Map<String, Map>> getAllOlmSessions();

  Future<List<OlmSession>> getOlmSessionsForDevices(
    List<String> identityKeys,
    String userId,
  );

  Future<List<QueuedToDeviceEvent>> getToDeviceEventQueue();

  /// Please do `jsonEncode(content)` in your code to stay compatible with
  /// auto generated methods here.
  Future insertIntoToDeviceQueue(
    String type,
    String txnId,
    String content,
  );

  Future<List<String>> getLastSentMessageUserDeviceKey(
    String userId,
    String deviceId,
  );

  Future<List<StoredInboundGroupSession>> getInboundGroupSessionsToUpload();

  Future<void> addSeenDeviceId(
      String userId, String deviceId, String publicKeys);

  Future<void> addSeenPublicKey(String publicKey, String deviceId);

  Future<String?> deviceIdSeen(userId, deviceId);

  Future<String?> publicKeySeen(String publicKey);

  Future<dynamic> close();

  Future<void> transaction(Future<void> Function() action);

  Future<String> exportDump();

  Future<bool> importDump(String export);

  Future<void> storePresence(String userId, CachedPresence presence);

  Future<CachedPresence?> getPresence(String userId);

  /// Deletes the whole database. The database needs to be created again after
  /// this. Used for migration only.
  Future<void> delete();
}
