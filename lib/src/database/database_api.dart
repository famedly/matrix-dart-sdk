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

import 'package:famedlysdk/encryption/utils/olm_session.dart';
import 'package:famedlysdk/encryption/utils/outbound_group_session.dart';
import 'package:famedlysdk/encryption/utils/session_key.dart';
import 'package:famedlysdk/encryption/utils/ssss_cache.dart';
import 'package:famedlysdk/encryption/utils/stored_inbound_group_session.dart';
import 'package:famedlysdk/src/utils/QueuedToDeviceEvent.dart';

import '../../famedlysdk.dart';

abstract class DatabaseApi {
  int get maxFileSize => 1 * 1024 * 1024;
  Future<dynamic> getClient(String name);

  Future<Map<String, DeviceKeysList>> getUserDeviceKeys(Client client);

  Future<OutboundGroupSession> getOutboundGroupSession(
    int clientId,
    String roomId,
    String userId,
  );

  Future<SessionKey> getInboundGroupSession(
    int clientId,
    String roomId,
    String sessionId,
    String userId,
  );

  Future<SSSSCache> getSSSSCache(int clientId, String type);

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

  Future<Uint8List> getFile(String mxcUri);

  Future<int> updateInboundGroupSessionIndexes(
    String indexes,
    int clientId,
    String roomId,
    String sessionId,
  );

  Future<int> storeInboundGroupSession(
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

  Future<int> markInboundGroupSessionAsUploaded(
    int clientId,
    String roomId,
    String sessionId,
  );

  Future<int> updateInboundGroupSessionAllowedAtIndex(
    String allowedAtIndex,
    int clientId,
    String roomId,
    String sessionId,
  );

  Future<int> removeOutboundGroupSession(int clientId, String roomId);

  Future<int> storeFile(String mxcUri, Uint8List bytes, int time);

  Future<int> updateClient(
    String homeserverUrl,
    String token,
    String userId,
    String deviceId,
    String deviceName,
    String prevBatch,
    String olmAccount,
    int clientId,
  );

  Future<int> insertClient(
    String name,
    String homeserverUrl,
    String token,
    String userId,
    String deviceId,
    String deviceName,
    String prevBatch,
    String olmAccount,
  );

  Future<int> storeSyncFilterId(String syncFilterId, int clientId);

  Future<int> storeAccountData(int clientId, String type, String content);

  Future<int> storeOutboundGroupSession(
    int clientId,
    String roomId,
    String pickle,
    String deviceIds,
    int creationTime,
    int sentMessages,
  );

  Future<int> updateClientKeys(String olmAccount, int clientId);

  Future<int> storeOlmSession(
    int clientId,
    String identitiyKey,
    String sessionId,
    String pickle,
    int lastReceived,
  );

  Future<int> setLastActiveUserDeviceKey(
    int lastActive,
    int clientId,
    String userId,
    String deviceId,
  );

  Future<int> setLastSentMessageUserDeviceKey(
    String lastSentMessage,
    int clientId,
    String userId,
    String deviceId,
  );

  Future<int> clearSSSSCache(int clientId);

  Future<int> storeSSSSCache(
    int clientId,
    String type,
    String keyId,
    String ciphertext,
    String content,
  );

  Future<int> markInboundGroupSessionsAsNeedingUpload(int clientId);

  Future<int> storePrevBatch(String prevBatch, int clientId);

  Future<int> deleteOldFiles(int savedAt);

  Future<int> storeUserDeviceKeysInfo(
    int clientId,
    String userId,
    bool outdated,
  );

  Future<int> storeUserDeviceKey(
    int clientId,
    String userId,
    String deviceId,
    String content,
    bool verified,
    bool blocked,
    int lastActive,
  );

  Future<int> removeUserDeviceKey(
    int clientId,
    String userId,
    String deviceId,
  );

  Future<int> removeUserCrossSigningKey(
    int clientId,
    String userId,
    String publicKey,
  );

  Future<int> storeUserCrossSigningKey(
    int clientId,
    String userId,
    String publicKey,
    String content,
    bool verified,
    bool blocked,
  );

  Future<int> deleteFromToDeviceQueue(int clientId, int id);

  Future<int> removeEvent(int clientId, String eventId, String roomId);

  Future<int> updateRoomSortOrder(
    double oldestSortOrder,
    double newestSortOrder,
    int clientId,
    String roomId,
  );

  Future<int> setRoomPrevBatch(
    String prevBatch,
    int clientId,
    String roomId,
  );

  Future<int> resetNotificationCount(int clientId, String roomId);

  Future<int> setVerifiedUserCrossSigningKey(
    bool verified,
    int clientId,
    String userId,
    String publicKey,
  );

  Future<int> setBlockedUserCrossSigningKey(
    bool blocked,
    int clientId,
    String userId,
    String publicKey,
  );

  Future<int> setVerifiedUserDeviceKey(
    bool verified,
    int clientId,
    String userId,
    String deviceId,
  );

  Future<int> setBlockedUserDeviceKey(
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
  Future<int> insertIntoToDeviceQueue(
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
