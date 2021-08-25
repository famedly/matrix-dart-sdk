// @dart=2.9
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
import 'package:matrix/src/utils/QueuedToDeviceEvent.dart';

import '../../matrix.dart';

abstract class DatabaseApi {
  int get maxFileSize => 1 * 1024 * 1024;
  bool get supportsFileStoring => false;
  Future<Map<String, dynamic>> getClient(String name);

  Future updateClient(
    String homeserverUrl,
    String token,
    String userId,
    String deviceId,
    String deviceName,
    String prevBatch,
    String olmAccount,
    int clientId,
  );

  Future insertClient(
    String name,
    String homeserverUrl,
    String token,
    String userId,
    String deviceId,
    String deviceName,
    String prevBatch,
    String olmAccount,
  );

  Future<List<Room>> getRoomList(Client client);

  Future<Map<String, BasicEvent>> getAccountData(int clientId);

  /// Stores a RoomUpdate object in the database. Must be called inside of
  /// [transaction].
  Future<void> storeRoomUpdate(int clientId, RoomUpdate roomUpdate,
      [Room oldRoom]);

  /// Stores an EventUpdate object in the database. Must be called inside of
  /// [transaction].
  Future<void> storeEventUpdate(int clientId, EventUpdate eventUpdate);

  Future<Event> getEventById(int clientId, String eventId, Room room);

  Future<void> forgetRoom(int clientId, String roomId);

  Future<void> clearCache(int clientId);

  Future<void> clear(int clientId);

  Future<User> getUser(int clientId, String userId, Room room);

  Future<List<User>> getUsers(int clientId, Room room);

  Future<List<Event>> getEventList(int clientId, Room room);

  Future<Uint8List> getFile(Uri mxcUri);

  Future storeFile(Uri mxcUri, Uint8List bytes, int time);

  Future storeSyncFilterId(String syncFilterId, int clientId);

  Future storeAccountData(int clientId, String type, String content);

  Future<Map<String, DeviceKeysList>> getUserDeviceKeys(Client client);

  Future<SSSSCache> getSSSSCache(int clientId, String type);

  Future<OutboundGroupSession> getOutboundGroupSession(
    int clientId,
    String roomId,
    String userId,
  );

  Future<List<StoredInboundGroupSession>> getAllInboundGroupSessions(
    int clientId,
  );

  Future<StoredInboundGroupSession> getInboundGroupSession(
    int clientId,
    String roomId,
    String sessionId,
  );

  Future updateInboundGroupSessionIndexes(
    String indexes,
    int clientId,
    String roomId,
    String sessionId,
  );

  Future storeInboundGroupSession(
    int clientId,
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
    int clientId,
    String roomId,
    String sessionId,
  );

  Future updateInboundGroupSessionAllowedAtIndex(
    String allowedAtIndex,
    int clientId,
    String roomId,
    String sessionId,
  );

  Future removeOutboundGroupSession(int clientId, String roomId);

  Future storeOutboundGroupSession(
    int clientId,
    String roomId,
    String pickle,
    String deviceIds,
    int creationTime,
    int sentMessages,
  );

  Future updateClientKeys(String olmAccount, int clientId);

  Future storeOlmSession(
    int clientId,
    String identitiyKey,
    String sessionId,
    String pickle,
    int lastReceived,
  );

  Future setLastActiveUserDeviceKey(
    int lastActive,
    int clientId,
    String userId,
    String deviceId,
  );

  Future setLastSentMessageUserDeviceKey(
    String lastSentMessage,
    int clientId,
    String userId,
    String deviceId,
  );

  Future clearSSSSCache(int clientId);

  Future storeSSSSCache(
    int clientId,
    String type,
    String keyId,
    String ciphertext,
    String content,
  );

  Future markInboundGroupSessionsAsNeedingUpload(int clientId);

  Future storePrevBatch(String prevBatch, int clientId);

  Future deleteOldFiles(int savedAt);

  Future storeUserDeviceKeysInfo(
    int clientId,
    String userId,
    bool outdated,
  );

  Future storeUserDeviceKey(
    int clientId,
    String userId,
    String deviceId,
    String content,
    bool verified,
    bool blocked,
    int lastActive,
  );

  Future removeUserDeviceKey(
    int clientId,
    String userId,
    String deviceId,
  );

  Future removeUserCrossSigningKey(
    int clientId,
    String userId,
    String publicKey,
  );

  Future storeUserCrossSigningKey(
    int clientId,
    String userId,
    String publicKey,
    String content,
    bool verified,
    bool blocked,
  );

  Future deleteFromToDeviceQueue(int clientId, int id);

  Future removeEvent(int clientId, String eventId, String roomId);

  Future updateRoomSortOrder(
    double oldestSortOrder,
    double newestSortOrder,
    int clientId,
    String roomId,
  );

  Future setRoomPrevBatch(
    String prevBatch,
    int clientId,
    String roomId,
  );

  Future resetNotificationCount(int clientId, String roomId);

  Future setVerifiedUserCrossSigningKey(
    bool verified,
    int clientId,
    String userId,
    String publicKey,
  );

  Future setBlockedUserCrossSigningKey(
    bool blocked,
    int clientId,
    String userId,
    String publicKey,
  );

  Future setVerifiedUserDeviceKey(
    bool verified,
    int clientId,
    String userId,
    String deviceId,
  );

  Future setBlockedUserDeviceKey(
    bool blocked,
    int clientId,
    String userId,
    String deviceId,
  );

  Future<List<Event>> getUnimportantRoomEventStatesForRoom(
    int clientId,
    List<String> events,
    Room room,
  );

  Future<List<OlmSession>> getOlmSessions(
    int clientId,
    String identityKey,
    String userId,
  );

  Future<List<OlmSession>> getOlmSessionsForDevices(
    int clientId,
    List<String> identityKeys,
    String userId,
  );

  Future<List<QueuedToDeviceEvent>> getToDeviceEventQueue(int clientId);

  /// Please do `jsonEncode(content)` in your code to stay compatible with
  /// auto generated methods here.
  Future insertIntoToDeviceQueue(
    int clientId,
    String type,
    String txnId,
    String content,
  );

  Future<List<String>> getLastSentMessageUserDeviceKey(
    int clientId,
    String userId,
    String deviceId,
  );

  Future<List<StoredInboundGroupSession>> getInboundGroupSessionsToUpload();

  Future<dynamic> close();

  Future<T> transaction<T>(Future<T> Function() action);
}
