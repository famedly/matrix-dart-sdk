import 'package:sqflite_common/sqflite.dart';

enum DbTables {
  client,
  rooms,
  timelineEvents,
  stateEvents,
  accountData,
  roomAccountData,
  toDeviceQueue,
  inboundGroupSessions,
  outboundGroupSessions,
  olmSessions,
  userDeviceKeys,
  userDeviceKeysInfo,
  userCrossSigningKeys,
  ssssCache,
  seenDeviceIds,
  seenDeviceKeys,
  presences,
}

extension DbTablesExtension on DbTables {
  Future<void> createTable(Database db) {
    switch (this) {
      case DbTables.client:
        return db.execute('''
        CREATE TABLE $name (key TEXT PRIMARY KEY NOT NULL, value TEXT)
        ''');
      case DbTables.rooms:
        return db.execute('''
        CREATE TABLE $name (
          id TEXT NOT NULL PRIMARY KEY,
          membership TEXT NOT NULL,
          notification_count INTEGER,
          highlight_count INTEGER,
          prev_batch TEXT,
          summary JSON
        )
        ''');
      case DbTables.timelineEvents:
        return db.execute('''
        CREATE TABLE $name (
          event_id TEXT NOT NULL,
          type TEXT NOT NULL,
          room_id TEXT NOT NULL,
          state_key TEXT,
          sender TEXT NOT NULL,
          origin_server_ts INTEGER,
          content JSON NOT NULL,
          unsigned JSON,
          prev_content JSON,
          original_source JSON,
          status INTEGER DEFAULT 2 NOT NULL,
          redacts TEXT,
          sort_order INTEGER NOT NULL,
          PRIMARY KEY (room_id, event_id)
        )
        ''');
      case DbTables.stateEvents:
        return db.execute('''
        CREATE TABLE $name (
          event_id TEXT,
          type TEXT NOT NULL,
          room_id TEXT NOT NULL,
          state_key TEXT,
          sender TEXT NOT NULL,
          origin_server_ts INTEGER,
          content JSON NOT NULL,
          unsigned JSON,
          prev_content JSON,
          original_source JSON,
          redacts TEXT,
          status INTEGER DEFAULT 2 NOT NULL,
          PRIMARY KEY (room_id, type, state_key)
        )
        ''');
      case DbTables.accountData:
        return db.execute('''
        CREATE TABLE $name (
          type TEXT NOT NULL PRIMARY KEY,
          content JSON NOT NULL
        )
        ''');
      case DbTables.roomAccountData:
        return db.execute('''
        CREATE TABLE $name (
          type TEXT NOT NULL,
          room_id TEXT NOT NULL,
          content JSON NOT NULL,
          PRIMARY KEY (room_id, type)
        )
        ''');
      case DbTables.toDeviceQueue:
        return db.execute('''
        CREATE TABLE $name (
          id INTEGER NOT NULL PRIMARY KEY,
          type TEXT NOT NULL,
          txn_id TEXT NOT NULL,
          content JSON NOT NULL
        )
        ''');
      case DbTables.inboundGroupSessions:
        return db.execute('''
        CREATE TABLE $name (
          session_id TEXT NOT NULL PRIMARY KEY,
          room_id TEXT NOT NULL,
          pickle TEXT NOT NULL,
          content TEXT NOT NULL,
          indexes TEXT NOT NULL,
          allowed_at_index TEXT NOT NULL,
          uploaded BOOLEAN NOT NULL,
          sender_key TEXT NOT NULL,
          sender_claimed_keys TEXT NOT NULL
        )
        ''');
      case DbTables.outboundGroupSessions:
        return db.execute('''
        CREATE TABLE $name (
          room_id TEXT NOT NULL PRIMARY KEY,
          pickle TEXT NOT NULL,
          device_ids JSON NOT NULL,
          creation_time INTEGER NOT NULL
        )
        ''');
      case DbTables.olmSessions:
        return db.execute('''
        CREATE TABLE $name (
          identity_key TEXT NOT NULL,
          session_id TEXT NOT NULL,
          pickle TEXT NOT NULL,
          last_received INTEGER NOT NULL,
          PRIMARY KEY (identity_key, session_id)
        )
        ''');
      case DbTables.userDeviceKeys:
        return db.execute('''
        CREATE TABLE $name (
          user_id TEXT NOT NULL,
          device_id TEXT NOT NULL,
          algorithms TEXT,
          verified BOOLEAN,
          blocked BOOLEAN,
          last_active INTEGER,
          last_sent_message TEXT,
          content JSON,
          PRIMARY KEY (user_id, device_id)
        )
        ''');
      case DbTables.userDeviceKeysInfo:
        return db.execute('''
        CREATE TABLE $name (
          user_id TEXT NOT NULL PRIMARY KEY,
          outdated BOOLEAN NOT NULL
        )
        ''');
      case DbTables.userCrossSigningKeys:
        return db.execute('''
        CREATE TABLE $name (
          user_id TEXT NOT NULL,
          public_key TEXT NOT NULL,
          verified BOOLEAN,
          blocked BOOLEAN,
          content JSON,
          PRIMARY KEY (user_id, public_key)
        )
        ''');
      case DbTables.ssssCache:
        return db.execute('''
        CREATE TABLE $name (
          type TEXT NOT NULL PRIMARY KEY,
          key_id TEXT NOT NULL,
          ciphertext TEXT NOT NULL,
          content TEXT NOT NULL
        )
        ''');
      case DbTables.seenDeviceIds:
        return db.execute('''
        CREATE TABLE $name (
          user_id TEXT NOT NULL,
          device_id TEXT NOT NULL,
          public_key TEXT NOT NULL,
          PRIMARY KEY (user_id, device_id)
        )
        ''');
      case DbTables.seenDeviceKeys:
        return db.execute('''
        CREATE TABLE $name (
          public_key TEXT NOT NULL,
          device_id TEXT NOT NULL,
          PRIMARY KEY (public_key)
        )
        ''');
      case DbTables.presences:
        return db.execute('''
        CREATE TABLE $name (
          user_id TEXT NOT NULL,
          presence TEXT NOT NULL,
          last_active_timestamp INTEGER,
          status_msg TEXT,
          currently_active BOOLEAN,
          PRIMARY KEY (user_id)
        )
        ''');
    }
  }

  static Future<void> create(Database db, int version) async {
    for (final table in DbTables.values) {
      await table.createTable(db);
    }
  }
}
