// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// **************************************************************************
// MoorGenerator
// **************************************************************************

// ignore_for_file: unnecessary_brace_in_string_interps, unnecessary_this
class DbClient extends DataClass implements Insertable<DbClient> {
  final int clientId;
  final String name;
  final String homeserverUrl;
  final String token;
  final String userId;
  final String deviceId;
  final String deviceName;
  final String prevBatch;
  final String olmAccount;
  DbClient(
      {@required this.clientId,
      @required this.name,
      @required this.homeserverUrl,
      @required this.token,
      @required this.userId,
      this.deviceId,
      this.deviceName,
      this.prevBatch,
      this.olmAccount});
  factory DbClient.fromData(Map<String, dynamic> data, GeneratedDatabase db,
      {String prefix}) {
    final effectivePrefix = prefix ?? '';
    final intType = db.typeSystem.forDartType<int>();
    final stringType = db.typeSystem.forDartType<String>();
    return DbClient(
      clientId:
          intType.mapFromDatabaseResponse(data['${effectivePrefix}client_id']),
      name: stringType.mapFromDatabaseResponse(data['${effectivePrefix}name']),
      homeserverUrl: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}homeserver_url']),
      token:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}token']),
      userId:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}user_id']),
      deviceId: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}device_id']),
      deviceName: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}device_name']),
      prevBatch: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}prev_batch']),
      olmAccount: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}olm_account']),
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || clientId != null) {
      map['client_id'] = Variable<int>(clientId);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || homeserverUrl != null) {
      map['homeserver_url'] = Variable<String>(homeserverUrl);
    }
    if (!nullToAbsent || token != null) {
      map['token'] = Variable<String>(token);
    }
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    if (!nullToAbsent || deviceName != null) {
      map['device_name'] = Variable<String>(deviceName);
    }
    if (!nullToAbsent || prevBatch != null) {
      map['prev_batch'] = Variable<String>(prevBatch);
    }
    if (!nullToAbsent || olmAccount != null) {
      map['olm_account'] = Variable<String>(olmAccount);
    }
    return map;
  }

  factory DbClient.fromJson(Map<String, dynamic> json,
      {ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return DbClient(
      clientId: serializer.fromJson<int>(json['client_id']),
      name: serializer.fromJson<String>(json['name']),
      homeserverUrl: serializer.fromJson<String>(json['homeserver_url']),
      token: serializer.fromJson<String>(json['token']),
      userId: serializer.fromJson<String>(json['user_id']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      deviceName: serializer.fromJson<String>(json['device_name']),
      prevBatch: serializer.fromJson<String>(json['prev_batch']),
      olmAccount: serializer.fromJson<String>(json['olm_account']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'client_id': serializer.toJson<int>(clientId),
      'name': serializer.toJson<String>(name),
      'homeserver_url': serializer.toJson<String>(homeserverUrl),
      'token': serializer.toJson<String>(token),
      'user_id': serializer.toJson<String>(userId),
      'device_id': serializer.toJson<String>(deviceId),
      'device_name': serializer.toJson<String>(deviceName),
      'prev_batch': serializer.toJson<String>(prevBatch),
      'olm_account': serializer.toJson<String>(olmAccount),
    };
  }

  DbClient copyWith(
          {int clientId,
          String name,
          String homeserverUrl,
          String token,
          String userId,
          String deviceId,
          String deviceName,
          String prevBatch,
          String olmAccount}) =>
      DbClient(
        clientId: clientId ?? this.clientId,
        name: name ?? this.name,
        homeserverUrl: homeserverUrl ?? this.homeserverUrl,
        token: token ?? this.token,
        userId: userId ?? this.userId,
        deviceId: deviceId ?? this.deviceId,
        deviceName: deviceName ?? this.deviceName,
        prevBatch: prevBatch ?? this.prevBatch,
        olmAccount: olmAccount ?? this.olmAccount,
      );
  @override
  String toString() {
    return (StringBuffer('DbClient(')
          ..write('clientId: $clientId, ')
          ..write('name: $name, ')
          ..write('homeserverUrl: $homeserverUrl, ')
          ..write('token: $token, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('deviceName: $deviceName, ')
          ..write('prevBatch: $prevBatch, ')
          ..write('olmAccount: $olmAccount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => $mrjf($mrjc(
      clientId.hashCode,
      $mrjc(
          name.hashCode,
          $mrjc(
              homeserverUrl.hashCode,
              $mrjc(
                  token.hashCode,
                  $mrjc(
                      userId.hashCode,
                      $mrjc(
                          deviceId.hashCode,
                          $mrjc(
                              deviceName.hashCode,
                              $mrjc(prevBatch.hashCode,
                                  olmAccount.hashCode)))))))));
  @override
  bool operator ==(dynamic other) =>
      identical(this, other) ||
      (other is DbClient &&
          other.clientId == this.clientId &&
          other.name == this.name &&
          other.homeserverUrl == this.homeserverUrl &&
          other.token == this.token &&
          other.userId == this.userId &&
          other.deviceId == this.deviceId &&
          other.deviceName == this.deviceName &&
          other.prevBatch == this.prevBatch &&
          other.olmAccount == this.olmAccount);
}

class ClientsCompanion extends UpdateCompanion<DbClient> {
  final Value<int> clientId;
  final Value<String> name;
  final Value<String> homeserverUrl;
  final Value<String> token;
  final Value<String> userId;
  final Value<String> deviceId;
  final Value<String> deviceName;
  final Value<String> prevBatch;
  final Value<String> olmAccount;
  const ClientsCompanion({
    this.clientId = const Value.absent(),
    this.name = const Value.absent(),
    this.homeserverUrl = const Value.absent(),
    this.token = const Value.absent(),
    this.userId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deviceName = const Value.absent(),
    this.prevBatch = const Value.absent(),
    this.olmAccount = const Value.absent(),
  });
  ClientsCompanion.insert({
    this.clientId = const Value.absent(),
    @required String name,
    @required String homeserverUrl,
    @required String token,
    @required String userId,
    this.deviceId = const Value.absent(),
    this.deviceName = const Value.absent(),
    this.prevBatch = const Value.absent(),
    this.olmAccount = const Value.absent(),
  })  : name = Value(name),
        homeserverUrl = Value(homeserverUrl),
        token = Value(token),
        userId = Value(userId);
  static Insertable<DbClient> custom({
    Expression<int> clientId,
    Expression<String> name,
    Expression<String> homeserverUrl,
    Expression<String> token,
    Expression<String> userId,
    Expression<String> deviceId,
    Expression<String> deviceName,
    Expression<String> prevBatch,
    Expression<String> olmAccount,
  }) {
    return RawValuesInsertable({
      if (clientId != null) 'client_id': clientId,
      if (name != null) 'name': name,
      if (homeserverUrl != null) 'homeserver_url': homeserverUrl,
      if (token != null) 'token': token,
      if (userId != null) 'user_id': userId,
      if (deviceId != null) 'device_id': deviceId,
      if (deviceName != null) 'device_name': deviceName,
      if (prevBatch != null) 'prev_batch': prevBatch,
      if (olmAccount != null) 'olm_account': olmAccount,
    });
  }

  ClientsCompanion copyWith(
      {Value<int> clientId,
      Value<String> name,
      Value<String> homeserverUrl,
      Value<String> token,
      Value<String> userId,
      Value<String> deviceId,
      Value<String> deviceName,
      Value<String> prevBatch,
      Value<String> olmAccount}) {
    return ClientsCompanion(
      clientId: clientId ?? this.clientId,
      name: name ?? this.name,
      homeserverUrl: homeserverUrl ?? this.homeserverUrl,
      token: token ?? this.token,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      prevBatch: prevBatch ?? this.prevBatch,
      olmAccount: olmAccount ?? this.olmAccount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientId.present) {
      map['client_id'] = Variable<int>(clientId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (homeserverUrl.present) {
      map['homeserver_url'] = Variable<String>(homeserverUrl.value);
    }
    if (token.present) {
      map['token'] = Variable<String>(token.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deviceName.present) {
      map['device_name'] = Variable<String>(deviceName.value);
    }
    if (prevBatch.present) {
      map['prev_batch'] = Variable<String>(prevBatch.value);
    }
    if (olmAccount.present) {
      map['olm_account'] = Variable<String>(olmAccount.value);
    }
    return map;
  }
}

class Clients extends Table with TableInfo<Clients, DbClient> {
  final GeneratedDatabase _db;
  final String _alias;
  Clients(this._db, [this._alias]);
  final VerificationMeta _clientIdMeta = const VerificationMeta('clientId');
  GeneratedIntColumn _clientId;
  GeneratedIntColumn get clientId => _clientId ??= _constructClientId();
  GeneratedIntColumn _constructClientId() {
    return GeneratedIntColumn('client_id', $tableName, false,
        declaredAsPrimaryKey: true,
        hasAutoIncrement: true,
        $customConstraints: 'NOT NULL PRIMARY KEY AUTOINCREMENT');
  }

  final VerificationMeta _nameMeta = const VerificationMeta('name');
  GeneratedTextColumn _name;
  GeneratedTextColumn get name => _name ??= _constructName();
  GeneratedTextColumn _constructName() {
    return GeneratedTextColumn('name', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _homeserverUrlMeta =
      const VerificationMeta('homeserverUrl');
  GeneratedTextColumn _homeserverUrl;
  GeneratedTextColumn get homeserverUrl =>
      _homeserverUrl ??= _constructHomeserverUrl();
  GeneratedTextColumn _constructHomeserverUrl() {
    return GeneratedTextColumn('homeserver_url', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _tokenMeta = const VerificationMeta('token');
  GeneratedTextColumn _token;
  GeneratedTextColumn get token => _token ??= _constructToken();
  GeneratedTextColumn _constructToken() {
    return GeneratedTextColumn('token', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _userIdMeta = const VerificationMeta('userId');
  GeneratedTextColumn _userId;
  GeneratedTextColumn get userId => _userId ??= _constructUserId();
  GeneratedTextColumn _constructUserId() {
    return GeneratedTextColumn('user_id', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _deviceIdMeta = const VerificationMeta('deviceId');
  GeneratedTextColumn _deviceId;
  GeneratedTextColumn get deviceId => _deviceId ??= _constructDeviceId();
  GeneratedTextColumn _constructDeviceId() {
    return GeneratedTextColumn('device_id', $tableName, true,
        $customConstraints: '');
  }

  final VerificationMeta _deviceNameMeta = const VerificationMeta('deviceName');
  GeneratedTextColumn _deviceName;
  GeneratedTextColumn get deviceName => _deviceName ??= _constructDeviceName();
  GeneratedTextColumn _constructDeviceName() {
    return GeneratedTextColumn('device_name', $tableName, true,
        $customConstraints: '');
  }

  final VerificationMeta _prevBatchMeta = const VerificationMeta('prevBatch');
  GeneratedTextColumn _prevBatch;
  GeneratedTextColumn get prevBatch => _prevBatch ??= _constructPrevBatch();
  GeneratedTextColumn _constructPrevBatch() {
    return GeneratedTextColumn('prev_batch', $tableName, true,
        $customConstraints: '');
  }

  final VerificationMeta _olmAccountMeta = const VerificationMeta('olmAccount');
  GeneratedTextColumn _olmAccount;
  GeneratedTextColumn get olmAccount => _olmAccount ??= _constructOlmAccount();
  GeneratedTextColumn _constructOlmAccount() {
    return GeneratedTextColumn('olm_account', $tableName, true,
        $customConstraints: '');
  }

  @override
  List<GeneratedColumn> get $columns => [
        clientId,
        name,
        homeserverUrl,
        token,
        userId,
        deviceId,
        deviceName,
        prevBatch,
        olmAccount
      ];
  @override
  Clients get asDslTable => this;
  @override
  String get $tableName => _alias ?? 'clients';
  @override
  final String actualTableName = 'clients';
  @override
  VerificationContext validateIntegrity(Insertable<DbClient> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id'], _clientIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name'], _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('homeserver_url')) {
      context.handle(
          _homeserverUrlMeta,
          homeserverUrl.isAcceptableOrUnknown(
              data['homeserver_url'], _homeserverUrlMeta));
    } else if (isInserting) {
      context.missing(_homeserverUrlMeta);
    }
    if (data.containsKey('token')) {
      context.handle(
          _tokenMeta, token.isAcceptableOrUnknown(data['token'], _tokenMeta));
    } else if (isInserting) {
      context.missing(_tokenMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id'], _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id'], _deviceIdMeta));
    }
    if (data.containsKey('device_name')) {
      context.handle(
          _deviceNameMeta,
          deviceName.isAcceptableOrUnknown(
              data['device_name'], _deviceNameMeta));
    }
    if (data.containsKey('prev_batch')) {
      context.handle(_prevBatchMeta,
          prevBatch.isAcceptableOrUnknown(data['prev_batch'], _prevBatchMeta));
    }
    if (data.containsKey('olm_account')) {
      context.handle(
          _olmAccountMeta,
          olmAccount.isAcceptableOrUnknown(
              data['olm_account'], _olmAccountMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientId};
  @override
  DbClient map(Map<String, dynamic> data, {String tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : null;
    return DbClient.fromData(data, _db, prefix: effectivePrefix);
  }

  @override
  Clients createAlias(String alias) {
    return Clients(_db, alias);
  }

  @override
  List<String> get customConstraints => const ['UNIQUE(name)'];
  @override
  bool get dontWriteConstraints => true;
}

class DbUserDeviceKey extends DataClass implements Insertable<DbUserDeviceKey> {
  final int clientId;
  final String userId;
  final bool outdated;
  DbUserDeviceKey(
      {@required this.clientId, @required this.userId, this.outdated});
  factory DbUserDeviceKey.fromData(
      Map<String, dynamic> data, GeneratedDatabase db,
      {String prefix}) {
    final effectivePrefix = prefix ?? '';
    final intType = db.typeSystem.forDartType<int>();
    final stringType = db.typeSystem.forDartType<String>();
    final boolType = db.typeSystem.forDartType<bool>();
    return DbUserDeviceKey(
      clientId:
          intType.mapFromDatabaseResponse(data['${effectivePrefix}client_id']),
      userId:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}user_id']),
      outdated:
          boolType.mapFromDatabaseResponse(data['${effectivePrefix}outdated']),
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || clientId != null) {
      map['client_id'] = Variable<int>(clientId);
    }
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || outdated != null) {
      map['outdated'] = Variable<bool>(outdated);
    }
    return map;
  }

  factory DbUserDeviceKey.fromJson(Map<String, dynamic> json,
      {ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return DbUserDeviceKey(
      clientId: serializer.fromJson<int>(json['client_id']),
      userId: serializer.fromJson<String>(json['user_id']),
      outdated: serializer.fromJson<bool>(json['outdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'client_id': serializer.toJson<int>(clientId),
      'user_id': serializer.toJson<String>(userId),
      'outdated': serializer.toJson<bool>(outdated),
    };
  }

  DbUserDeviceKey copyWith({int clientId, String userId, bool outdated}) =>
      DbUserDeviceKey(
        clientId: clientId ?? this.clientId,
        userId: userId ?? this.userId,
        outdated: outdated ?? this.outdated,
      );
  @override
  String toString() {
    return (StringBuffer('DbUserDeviceKey(')
          ..write('clientId: $clientId, ')
          ..write('userId: $userId, ')
          ..write('outdated: $outdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => $mrjf(
      $mrjc(clientId.hashCode, $mrjc(userId.hashCode, outdated.hashCode)));
  @override
  bool operator ==(dynamic other) =>
      identical(this, other) ||
      (other is DbUserDeviceKey &&
          other.clientId == this.clientId &&
          other.userId == this.userId &&
          other.outdated == this.outdated);
}

class UserDeviceKeysCompanion extends UpdateCompanion<DbUserDeviceKey> {
  final Value<int> clientId;
  final Value<String> userId;
  final Value<bool> outdated;
  const UserDeviceKeysCompanion({
    this.clientId = const Value.absent(),
    this.userId = const Value.absent(),
    this.outdated = const Value.absent(),
  });
  UserDeviceKeysCompanion.insert({
    @required int clientId,
    @required String userId,
    this.outdated = const Value.absent(),
  })  : clientId = Value(clientId),
        userId = Value(userId);
  static Insertable<DbUserDeviceKey> custom({
    Expression<int> clientId,
    Expression<String> userId,
    Expression<bool> outdated,
  }) {
    return RawValuesInsertable({
      if (clientId != null) 'client_id': clientId,
      if (userId != null) 'user_id': userId,
      if (outdated != null) 'outdated': outdated,
    });
  }

  UserDeviceKeysCompanion copyWith(
      {Value<int> clientId, Value<String> userId, Value<bool> outdated}) {
    return UserDeviceKeysCompanion(
      clientId: clientId ?? this.clientId,
      userId: userId ?? this.userId,
      outdated: outdated ?? this.outdated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientId.present) {
      map['client_id'] = Variable<int>(clientId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (outdated.present) {
      map['outdated'] = Variable<bool>(outdated.value);
    }
    return map;
  }
}

class UserDeviceKeys extends Table
    with TableInfo<UserDeviceKeys, DbUserDeviceKey> {
  final GeneratedDatabase _db;
  final String _alias;
  UserDeviceKeys(this._db, [this._alias]);
  final VerificationMeta _clientIdMeta = const VerificationMeta('clientId');
  GeneratedIntColumn _clientId;
  GeneratedIntColumn get clientId => _clientId ??= _constructClientId();
  GeneratedIntColumn _constructClientId() {
    return GeneratedIntColumn('client_id', $tableName, false,
        $customConstraints: 'NOT NULL REFERENCES clients(client_id)');
  }

  final VerificationMeta _userIdMeta = const VerificationMeta('userId');
  GeneratedTextColumn _userId;
  GeneratedTextColumn get userId => _userId ??= _constructUserId();
  GeneratedTextColumn _constructUserId() {
    return GeneratedTextColumn('user_id', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _outdatedMeta = const VerificationMeta('outdated');
  GeneratedBoolColumn _outdated;
  GeneratedBoolColumn get outdated => _outdated ??= _constructOutdated();
  GeneratedBoolColumn _constructOutdated() {
    return GeneratedBoolColumn('outdated', $tableName, true,
        $customConstraints: 'DEFAULT true',
        defaultValue: const CustomExpression<bool>('true'));
  }

  @override
  List<GeneratedColumn> get $columns => [clientId, userId, outdated];
  @override
  UserDeviceKeys get asDslTable => this;
  @override
  String get $tableName => _alias ?? 'user_device_keys';
  @override
  final String actualTableName = 'user_device_keys';
  @override
  VerificationContext validateIntegrity(Insertable<DbUserDeviceKey> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id'], _clientIdMeta));
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id'], _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('outdated')) {
      context.handle(_outdatedMeta,
          outdated.isAcceptableOrUnknown(data['outdated'], _outdatedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => <GeneratedColumn>{};
  @override
  DbUserDeviceKey map(Map<String, dynamic> data, {String tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : null;
    return DbUserDeviceKey.fromData(data, _db, prefix: effectivePrefix);
  }

  @override
  UserDeviceKeys createAlias(String alias) {
    return UserDeviceKeys(_db, alias);
  }

  @override
  List<String> get customConstraints => const ['UNIQUE(client_id, user_id)'];
  @override
  bool get dontWriteConstraints => true;
}

class DbUserDeviceKeysKey extends DataClass
    implements Insertable<DbUserDeviceKeysKey> {
  final int clientId;
  final String userId;
  final String deviceId;
  final String content;
  final bool verified;
  final bool blocked;
  DbUserDeviceKeysKey(
      {@required this.clientId,
      @required this.userId,
      @required this.deviceId,
      @required this.content,
      this.verified,
      this.blocked});
  factory DbUserDeviceKeysKey.fromData(
      Map<String, dynamic> data, GeneratedDatabase db,
      {String prefix}) {
    final effectivePrefix = prefix ?? '';
    final intType = db.typeSystem.forDartType<int>();
    final stringType = db.typeSystem.forDartType<String>();
    final boolType = db.typeSystem.forDartType<bool>();
    return DbUserDeviceKeysKey(
      clientId:
          intType.mapFromDatabaseResponse(data['${effectivePrefix}client_id']),
      userId:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}user_id']),
      deviceId: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}device_id']),
      content:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}content']),
      verified:
          boolType.mapFromDatabaseResponse(data['${effectivePrefix}verified']),
      blocked:
          boolType.mapFromDatabaseResponse(data['${effectivePrefix}blocked']),
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || clientId != null) {
      map['client_id'] = Variable<int>(clientId);
    }
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || verified != null) {
      map['verified'] = Variable<bool>(verified);
    }
    if (!nullToAbsent || blocked != null) {
      map['blocked'] = Variable<bool>(blocked);
    }
    return map;
  }

  factory DbUserDeviceKeysKey.fromJson(Map<String, dynamic> json,
      {ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return DbUserDeviceKeysKey(
      clientId: serializer.fromJson<int>(json['client_id']),
      userId: serializer.fromJson<String>(json['user_id']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      content: serializer.fromJson<String>(json['content']),
      verified: serializer.fromJson<bool>(json['verified']),
      blocked: serializer.fromJson<bool>(json['blocked']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'client_id': serializer.toJson<int>(clientId),
      'user_id': serializer.toJson<String>(userId),
      'device_id': serializer.toJson<String>(deviceId),
      'content': serializer.toJson<String>(content),
      'verified': serializer.toJson<bool>(verified),
      'blocked': serializer.toJson<bool>(blocked),
    };
  }

  DbUserDeviceKeysKey copyWith(
          {int clientId,
          String userId,
          String deviceId,
          String content,
          bool verified,
          bool blocked}) =>
      DbUserDeviceKeysKey(
        clientId: clientId ?? this.clientId,
        userId: userId ?? this.userId,
        deviceId: deviceId ?? this.deviceId,
        content: content ?? this.content,
        verified: verified ?? this.verified,
        blocked: blocked ?? this.blocked,
      );
  @override
  String toString() {
    return (StringBuffer('DbUserDeviceKeysKey(')
          ..write('clientId: $clientId, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('content: $content, ')
          ..write('verified: $verified, ')
          ..write('blocked: $blocked')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => $mrjf($mrjc(
      clientId.hashCode,
      $mrjc(
          userId.hashCode,
          $mrjc(
              deviceId.hashCode,
              $mrjc(content.hashCode,
                  $mrjc(verified.hashCode, blocked.hashCode))))));
  @override
  bool operator ==(dynamic other) =>
      identical(this, other) ||
      (other is DbUserDeviceKeysKey &&
          other.clientId == this.clientId &&
          other.userId == this.userId &&
          other.deviceId == this.deviceId &&
          other.content == this.content &&
          other.verified == this.verified &&
          other.blocked == this.blocked);
}

class UserDeviceKeysKeyCompanion extends UpdateCompanion<DbUserDeviceKeysKey> {
  final Value<int> clientId;
  final Value<String> userId;
  final Value<String> deviceId;
  final Value<String> content;
  final Value<bool> verified;
  final Value<bool> blocked;
  const UserDeviceKeysKeyCompanion({
    this.clientId = const Value.absent(),
    this.userId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.content = const Value.absent(),
    this.verified = const Value.absent(),
    this.blocked = const Value.absent(),
  });
  UserDeviceKeysKeyCompanion.insert({
    @required int clientId,
    @required String userId,
    @required String deviceId,
    @required String content,
    this.verified = const Value.absent(),
    this.blocked = const Value.absent(),
  })  : clientId = Value(clientId),
        userId = Value(userId),
        deviceId = Value(deviceId),
        content = Value(content);
  static Insertable<DbUserDeviceKeysKey> custom({
    Expression<int> clientId,
    Expression<String> userId,
    Expression<String> deviceId,
    Expression<String> content,
    Expression<bool> verified,
    Expression<bool> blocked,
  }) {
    return RawValuesInsertable({
      if (clientId != null) 'client_id': clientId,
      if (userId != null) 'user_id': userId,
      if (deviceId != null) 'device_id': deviceId,
      if (content != null) 'content': content,
      if (verified != null) 'verified': verified,
      if (blocked != null) 'blocked': blocked,
    });
  }

  UserDeviceKeysKeyCompanion copyWith(
      {Value<int> clientId,
      Value<String> userId,
      Value<String> deviceId,
      Value<String> content,
      Value<bool> verified,
      Value<bool> blocked}) {
    return UserDeviceKeysKeyCompanion(
      clientId: clientId ?? this.clientId,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      content: content ?? this.content,
      verified: verified ?? this.verified,
      blocked: blocked ?? this.blocked,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientId.present) {
      map['client_id'] = Variable<int>(clientId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (verified.present) {
      map['verified'] = Variable<bool>(verified.value);
    }
    if (blocked.present) {
      map['blocked'] = Variable<bool>(blocked.value);
    }
    return map;
  }
}

class UserDeviceKeysKey extends Table
    with TableInfo<UserDeviceKeysKey, DbUserDeviceKeysKey> {
  final GeneratedDatabase _db;
  final String _alias;
  UserDeviceKeysKey(this._db, [this._alias]);
  final VerificationMeta _clientIdMeta = const VerificationMeta('clientId');
  GeneratedIntColumn _clientId;
  GeneratedIntColumn get clientId => _clientId ??= _constructClientId();
  GeneratedIntColumn _constructClientId() {
    return GeneratedIntColumn('client_id', $tableName, false,
        $customConstraints: 'NOT NULL REFERENCES clients(client_id)');
  }

  final VerificationMeta _userIdMeta = const VerificationMeta('userId');
  GeneratedTextColumn _userId;
  GeneratedTextColumn get userId => _userId ??= _constructUserId();
  GeneratedTextColumn _constructUserId() {
    return GeneratedTextColumn('user_id', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _deviceIdMeta = const VerificationMeta('deviceId');
  GeneratedTextColumn _deviceId;
  GeneratedTextColumn get deviceId => _deviceId ??= _constructDeviceId();
  GeneratedTextColumn _constructDeviceId() {
    return GeneratedTextColumn('device_id', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _contentMeta = const VerificationMeta('content');
  GeneratedTextColumn _content;
  GeneratedTextColumn get content => _content ??= _constructContent();
  GeneratedTextColumn _constructContent() {
    return GeneratedTextColumn('content', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _verifiedMeta = const VerificationMeta('verified');
  GeneratedBoolColumn _verified;
  GeneratedBoolColumn get verified => _verified ??= _constructVerified();
  GeneratedBoolColumn _constructVerified() {
    return GeneratedBoolColumn('verified', $tableName, true,
        $customConstraints: 'DEFAULT false',
        defaultValue: const CustomExpression<bool>('false'));
  }

  final VerificationMeta _blockedMeta = const VerificationMeta('blocked');
  GeneratedBoolColumn _blocked;
  GeneratedBoolColumn get blocked => _blocked ??= _constructBlocked();
  GeneratedBoolColumn _constructBlocked() {
    return GeneratedBoolColumn('blocked', $tableName, true,
        $customConstraints: 'DEFAULT false',
        defaultValue: const CustomExpression<bool>('false'));
  }

  @override
  List<GeneratedColumn> get $columns =>
      [clientId, userId, deviceId, content, verified, blocked];
  @override
  UserDeviceKeysKey get asDslTable => this;
  @override
  String get $tableName => _alias ?? 'user_device_keys_key';
  @override
  final String actualTableName = 'user_device_keys_key';
  @override
  VerificationContext validateIntegrity(
      Insertable<DbUserDeviceKeysKey> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id'], _clientIdMeta));
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id'], _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id'], _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content'], _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('verified')) {
      context.handle(_verifiedMeta,
          verified.isAcceptableOrUnknown(data['verified'], _verifiedMeta));
    }
    if (data.containsKey('blocked')) {
      context.handle(_blockedMeta,
          blocked.isAcceptableOrUnknown(data['blocked'], _blockedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => <GeneratedColumn>{};
  @override
  DbUserDeviceKeysKey map(Map<String, dynamic> data, {String tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : null;
    return DbUserDeviceKeysKey.fromData(data, _db, prefix: effectivePrefix);
  }

  @override
  UserDeviceKeysKey createAlias(String alias) {
    return UserDeviceKeysKey(_db, alias);
  }

  @override
  List<String> get customConstraints =>
      const ['UNIQUE(client_id, user_id, device_id)'];
  @override
  bool get dontWriteConstraints => true;
}

class DbUserCrossSigningKey extends DataClass
    implements Insertable<DbUserCrossSigningKey> {
  final int clientId;
  final String userId;
  final String publicKey;
  final String content;
  final bool verified;
  final bool blocked;
  DbUserCrossSigningKey(
      {@required this.clientId,
      @required this.userId,
      @required this.publicKey,
      @required this.content,
      this.verified,
      this.blocked});
  factory DbUserCrossSigningKey.fromData(
      Map<String, dynamic> data, GeneratedDatabase db,
      {String prefix}) {
    final effectivePrefix = prefix ?? '';
    final intType = db.typeSystem.forDartType<int>();
    final stringType = db.typeSystem.forDartType<String>();
    final boolType = db.typeSystem.forDartType<bool>();
    return DbUserCrossSigningKey(
      clientId:
          intType.mapFromDatabaseResponse(data['${effectivePrefix}client_id']),
      userId:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}user_id']),
      publicKey: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}public_key']),
      content:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}content']),
      verified:
          boolType.mapFromDatabaseResponse(data['${effectivePrefix}verified']),
      blocked:
          boolType.mapFromDatabaseResponse(data['${effectivePrefix}blocked']),
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || clientId != null) {
      map['client_id'] = Variable<int>(clientId);
    }
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || publicKey != null) {
      map['public_key'] = Variable<String>(publicKey);
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || verified != null) {
      map['verified'] = Variable<bool>(verified);
    }
    if (!nullToAbsent || blocked != null) {
      map['blocked'] = Variable<bool>(blocked);
    }
    return map;
  }

  factory DbUserCrossSigningKey.fromJson(Map<String, dynamic> json,
      {ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return DbUserCrossSigningKey(
      clientId: serializer.fromJson<int>(json['client_id']),
      userId: serializer.fromJson<String>(json['user_id']),
      publicKey: serializer.fromJson<String>(json['public_key']),
      content: serializer.fromJson<String>(json['content']),
      verified: serializer.fromJson<bool>(json['verified']),
      blocked: serializer.fromJson<bool>(json['blocked']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'client_id': serializer.toJson<int>(clientId),
      'user_id': serializer.toJson<String>(userId),
      'public_key': serializer.toJson<String>(publicKey),
      'content': serializer.toJson<String>(content),
      'verified': serializer.toJson<bool>(verified),
      'blocked': serializer.toJson<bool>(blocked),
    };
  }

  DbUserCrossSigningKey copyWith(
          {int clientId,
          String userId,
          String publicKey,
          String content,
          bool verified,
          bool blocked}) =>
      DbUserCrossSigningKey(
        clientId: clientId ?? this.clientId,
        userId: userId ?? this.userId,
        publicKey: publicKey ?? this.publicKey,
        content: content ?? this.content,
        verified: verified ?? this.verified,
        blocked: blocked ?? this.blocked,
      );
  @override
  String toString() {
    return (StringBuffer('DbUserCrossSigningKey(')
          ..write('clientId: $clientId, ')
          ..write('userId: $userId, ')
          ..write('publicKey: $publicKey, ')
          ..write('content: $content, ')
          ..write('verified: $verified, ')
          ..write('blocked: $blocked')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => $mrjf($mrjc(
      clientId.hashCode,
      $mrjc(
          userId.hashCode,
          $mrjc(
              publicKey.hashCode,
              $mrjc(content.hashCode,
                  $mrjc(verified.hashCode, blocked.hashCode))))));
  @override
  bool operator ==(dynamic other) =>
      identical(this, other) ||
      (other is DbUserCrossSigningKey &&
          other.clientId == this.clientId &&
          other.userId == this.userId &&
          other.publicKey == this.publicKey &&
          other.content == this.content &&
          other.verified == this.verified &&
          other.blocked == this.blocked);
}

class UserCrossSigningKeysCompanion
    extends UpdateCompanion<DbUserCrossSigningKey> {
  final Value<int> clientId;
  final Value<String> userId;
  final Value<String> publicKey;
  final Value<String> content;
  final Value<bool> verified;
  final Value<bool> blocked;
  const UserCrossSigningKeysCompanion({
    this.clientId = const Value.absent(),
    this.userId = const Value.absent(),
    this.publicKey = const Value.absent(),
    this.content = const Value.absent(),
    this.verified = const Value.absent(),
    this.blocked = const Value.absent(),
  });
  UserCrossSigningKeysCompanion.insert({
    @required int clientId,
    @required String userId,
    @required String publicKey,
    @required String content,
    this.verified = const Value.absent(),
    this.blocked = const Value.absent(),
  })  : clientId = Value(clientId),
        userId = Value(userId),
        publicKey = Value(publicKey),
        content = Value(content);
  static Insertable<DbUserCrossSigningKey> custom({
    Expression<int> clientId,
    Expression<String> userId,
    Expression<String> publicKey,
    Expression<String> content,
    Expression<bool> verified,
    Expression<bool> blocked,
  }) {
    return RawValuesInsertable({
      if (clientId != null) 'client_id': clientId,
      if (userId != null) 'user_id': userId,
      if (publicKey != null) 'public_key': publicKey,
      if (content != null) 'content': content,
      if (verified != null) 'verified': verified,
      if (blocked != null) 'blocked': blocked,
    });
  }

  UserCrossSigningKeysCompanion copyWith(
      {Value<int> clientId,
      Value<String> userId,
      Value<String> publicKey,
      Value<String> content,
      Value<bool> verified,
      Value<bool> blocked}) {
    return UserCrossSigningKeysCompanion(
      clientId: clientId ?? this.clientId,
      userId: userId ?? this.userId,
      publicKey: publicKey ?? this.publicKey,
      content: content ?? this.content,
      verified: verified ?? this.verified,
      blocked: blocked ?? this.blocked,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientId.present) {
      map['client_id'] = Variable<int>(clientId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (publicKey.present) {
      map['public_key'] = Variable<String>(publicKey.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (verified.present) {
      map['verified'] = Variable<bool>(verified.value);
    }
    if (blocked.present) {
      map['blocked'] = Variable<bool>(blocked.value);
    }
    return map;
  }
}

class UserCrossSigningKeys extends Table
    with TableInfo<UserCrossSigningKeys, DbUserCrossSigningKey> {
  final GeneratedDatabase _db;
  final String _alias;
  UserCrossSigningKeys(this._db, [this._alias]);
  final VerificationMeta _clientIdMeta = const VerificationMeta('clientId');
  GeneratedIntColumn _clientId;
  GeneratedIntColumn get clientId => _clientId ??= _constructClientId();
  GeneratedIntColumn _constructClientId() {
    return GeneratedIntColumn('client_id', $tableName, false,
        $customConstraints: 'NOT NULL REFERENCES clients(client_id)');
  }

  final VerificationMeta _userIdMeta = const VerificationMeta('userId');
  GeneratedTextColumn _userId;
  GeneratedTextColumn get userId => _userId ??= _constructUserId();
  GeneratedTextColumn _constructUserId() {
    return GeneratedTextColumn('user_id', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _publicKeyMeta = const VerificationMeta('publicKey');
  GeneratedTextColumn _publicKey;
  GeneratedTextColumn get publicKey => _publicKey ??= _constructPublicKey();
  GeneratedTextColumn _constructPublicKey() {
    return GeneratedTextColumn('public_key', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _contentMeta = const VerificationMeta('content');
  GeneratedTextColumn _content;
  GeneratedTextColumn get content => _content ??= _constructContent();
  GeneratedTextColumn _constructContent() {
    return GeneratedTextColumn('content', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _verifiedMeta = const VerificationMeta('verified');
  GeneratedBoolColumn _verified;
  GeneratedBoolColumn get verified => _verified ??= _constructVerified();
  GeneratedBoolColumn _constructVerified() {
    return GeneratedBoolColumn('verified', $tableName, true,
        $customConstraints: 'DEFAULT false',
        defaultValue: const CustomExpression<bool>('false'));
  }

  final VerificationMeta _blockedMeta = const VerificationMeta('blocked');
  GeneratedBoolColumn _blocked;
  GeneratedBoolColumn get blocked => _blocked ??= _constructBlocked();
  GeneratedBoolColumn _constructBlocked() {
    return GeneratedBoolColumn('blocked', $tableName, true,
        $customConstraints: 'DEFAULT false',
        defaultValue: const CustomExpression<bool>('false'));
  }

  @override
  List<GeneratedColumn> get $columns =>
      [clientId, userId, publicKey, content, verified, blocked];
  @override
  UserCrossSigningKeys get asDslTable => this;
  @override
  String get $tableName => _alias ?? 'user_cross_signing_keys';
  @override
  final String actualTableName = 'user_cross_signing_keys';
  @override
  VerificationContext validateIntegrity(
      Insertable<DbUserCrossSigningKey> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id'], _clientIdMeta));
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id'], _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('public_key')) {
      context.handle(_publicKeyMeta,
          publicKey.isAcceptableOrUnknown(data['public_key'], _publicKeyMeta));
    } else if (isInserting) {
      context.missing(_publicKeyMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content'], _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('verified')) {
      context.handle(_verifiedMeta,
          verified.isAcceptableOrUnknown(data['verified'], _verifiedMeta));
    }
    if (data.containsKey('blocked')) {
      context.handle(_blockedMeta,
          blocked.isAcceptableOrUnknown(data['blocked'], _blockedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => <GeneratedColumn>{};
  @override
  DbUserCrossSigningKey map(Map<String, dynamic> data, {String tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : null;
    return DbUserCrossSigningKey.fromData(data, _db, prefix: effectivePrefix);
  }

  @override
  UserCrossSigningKeys createAlias(String alias) {
    return UserCrossSigningKeys(_db, alias);
  }

  @override
  List<String> get customConstraints =>
      const ['UNIQUE(client_id, user_id, public_key)'];
  @override
  bool get dontWriteConstraints => true;
}

class DbOlmSessions extends DataClass implements Insertable<DbOlmSessions> {
  final int clientId;
  final String identityKey;
  final String sessionId;
  final String pickle;
  final DateTime lastReceived;
  DbOlmSessions(
      {@required this.clientId,
      @required this.identityKey,
      @required this.sessionId,
      @required this.pickle,
      this.lastReceived});
  factory DbOlmSessions.fromData(
      Map<String, dynamic> data, GeneratedDatabase db,
      {String prefix}) {
    final effectivePrefix = prefix ?? '';
    final intType = db.typeSystem.forDartType<int>();
    final stringType = db.typeSystem.forDartType<String>();
    final dateTimeType = db.typeSystem.forDartType<DateTime>();
    return DbOlmSessions(
      clientId:
          intType.mapFromDatabaseResponse(data['${effectivePrefix}client_id']),
      identityKey: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}identity_key']),
      sessionId: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}session_id']),
      pickle:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}pickle']),
      lastReceived: dateTimeType
          .mapFromDatabaseResponse(data['${effectivePrefix}last_received']),
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || clientId != null) {
      map['client_id'] = Variable<int>(clientId);
    }
    if (!nullToAbsent || identityKey != null) {
      map['identity_key'] = Variable<String>(identityKey);
    }
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    if (!nullToAbsent || pickle != null) {
      map['pickle'] = Variable<String>(pickle);
    }
    if (!nullToAbsent || lastReceived != null) {
      map['last_received'] = Variable<DateTime>(lastReceived);
    }
    return map;
  }

  factory DbOlmSessions.fromJson(Map<String, dynamic> json,
      {ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return DbOlmSessions(
      clientId: serializer.fromJson<int>(json['client_id']),
      identityKey: serializer.fromJson<String>(json['identity_key']),
      sessionId: serializer.fromJson<String>(json['session_id']),
      pickle: serializer.fromJson<String>(json['pickle']),
      lastReceived: serializer.fromJson<DateTime>(json['last_received']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'client_id': serializer.toJson<int>(clientId),
      'identity_key': serializer.toJson<String>(identityKey),
      'session_id': serializer.toJson<String>(sessionId),
      'pickle': serializer.toJson<String>(pickle),
      'last_received': serializer.toJson<DateTime>(lastReceived),
    };
  }

  DbOlmSessions copyWith(
          {int clientId,
          String identityKey,
          String sessionId,
          String pickle,
          DateTime lastReceived}) =>
      DbOlmSessions(
        clientId: clientId ?? this.clientId,
        identityKey: identityKey ?? this.identityKey,
        sessionId: sessionId ?? this.sessionId,
        pickle: pickle ?? this.pickle,
        lastReceived: lastReceived ?? this.lastReceived,
      );
  @override
  String toString() {
    return (StringBuffer('DbOlmSessions(')
          ..write('clientId: $clientId, ')
          ..write('identityKey: $identityKey, ')
          ..write('sessionId: $sessionId, ')
          ..write('pickle: $pickle, ')
          ..write('lastReceived: $lastReceived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => $mrjf($mrjc(
      clientId.hashCode,
      $mrjc(
          identityKey.hashCode,
          $mrjc(sessionId.hashCode,
              $mrjc(pickle.hashCode, lastReceived.hashCode)))));
  @override
  bool operator ==(dynamic other) =>
      identical(this, other) ||
      (other is DbOlmSessions &&
          other.clientId == this.clientId &&
          other.identityKey == this.identityKey &&
          other.sessionId == this.sessionId &&
          other.pickle == this.pickle &&
          other.lastReceived == this.lastReceived);
}

class OlmSessionsCompanion extends UpdateCompanion<DbOlmSessions> {
  final Value<int> clientId;
  final Value<String> identityKey;
  final Value<String> sessionId;
  final Value<String> pickle;
  final Value<DateTime> lastReceived;
  const OlmSessionsCompanion({
    this.clientId = const Value.absent(),
    this.identityKey = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.pickle = const Value.absent(),
    this.lastReceived = const Value.absent(),
  });
  OlmSessionsCompanion.insert({
    @required int clientId,
    @required String identityKey,
    @required String sessionId,
    @required String pickle,
    this.lastReceived = const Value.absent(),
  })  : clientId = Value(clientId),
        identityKey = Value(identityKey),
        sessionId = Value(sessionId),
        pickle = Value(pickle);
  static Insertable<DbOlmSessions> custom({
    Expression<int> clientId,
    Expression<String> identityKey,
    Expression<String> sessionId,
    Expression<String> pickle,
    Expression<DateTime> lastReceived,
  }) {
    return RawValuesInsertable({
      if (clientId != null) 'client_id': clientId,
      if (identityKey != null) 'identity_key': identityKey,
      if (sessionId != null) 'session_id': sessionId,
      if (pickle != null) 'pickle': pickle,
      if (lastReceived != null) 'last_received': lastReceived,
    });
  }

  OlmSessionsCompanion copyWith(
      {Value<int> clientId,
      Value<String> identityKey,
      Value<String> sessionId,
      Value<String> pickle,
      Value<DateTime> lastReceived}) {
    return OlmSessionsCompanion(
      clientId: clientId ?? this.clientId,
      identityKey: identityKey ?? this.identityKey,
      sessionId: sessionId ?? this.sessionId,
      pickle: pickle ?? this.pickle,
      lastReceived: lastReceived ?? this.lastReceived,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientId.present) {
      map['client_id'] = Variable<int>(clientId.value);
    }
    if (identityKey.present) {
      map['identity_key'] = Variable<String>(identityKey.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (pickle.present) {
      map['pickle'] = Variable<String>(pickle.value);
    }
    if (lastReceived.present) {
      map['last_received'] = Variable<DateTime>(lastReceived.value);
    }
    return map;
  }
}

class OlmSessions extends Table with TableInfo<OlmSessions, DbOlmSessions> {
  final GeneratedDatabase _db;
  final String _alias;
  OlmSessions(this._db, [this._alias]);
  final VerificationMeta _clientIdMeta = const VerificationMeta('clientId');
  GeneratedIntColumn _clientId;
  GeneratedIntColumn get clientId => _clientId ??= _constructClientId();
  GeneratedIntColumn _constructClientId() {
    return GeneratedIntColumn('client_id', $tableName, false,
        $customConstraints: 'NOT NULL REFERENCES clients(client_id)');
  }

  final VerificationMeta _identityKeyMeta =
      const VerificationMeta('identityKey');
  GeneratedTextColumn _identityKey;
  GeneratedTextColumn get identityKey =>
      _identityKey ??= _constructIdentityKey();
  GeneratedTextColumn _constructIdentityKey() {
    return GeneratedTextColumn('identity_key', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _sessionIdMeta = const VerificationMeta('sessionId');
  GeneratedTextColumn _sessionId;
  GeneratedTextColumn get sessionId => _sessionId ??= _constructSessionId();
  GeneratedTextColumn _constructSessionId() {
    return GeneratedTextColumn('session_id', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _pickleMeta = const VerificationMeta('pickle');
  GeneratedTextColumn _pickle;
  GeneratedTextColumn get pickle => _pickle ??= _constructPickle();
  GeneratedTextColumn _constructPickle() {
    return GeneratedTextColumn('pickle', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _lastReceivedMeta =
      const VerificationMeta('lastReceived');
  GeneratedDateTimeColumn _lastReceived;
  GeneratedDateTimeColumn get lastReceived =>
      _lastReceived ??= _constructLastReceived();
  GeneratedDateTimeColumn _constructLastReceived() {
    return GeneratedDateTimeColumn('last_received', $tableName, true,
        $customConstraints: '');
  }

  @override
  List<GeneratedColumn> get $columns =>
      [clientId, identityKey, sessionId, pickle, lastReceived];
  @override
  OlmSessions get asDslTable => this;
  @override
  String get $tableName => _alias ?? 'olm_sessions';
  @override
  final String actualTableName = 'olm_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<DbOlmSessions> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id'], _clientIdMeta));
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('identity_key')) {
      context.handle(
          _identityKeyMeta,
          identityKey.isAcceptableOrUnknown(
              data['identity_key'], _identityKeyMeta));
    } else if (isInserting) {
      context.missing(_identityKeyMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id'], _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('pickle')) {
      context.handle(_pickleMeta,
          pickle.isAcceptableOrUnknown(data['pickle'], _pickleMeta));
    } else if (isInserting) {
      context.missing(_pickleMeta);
    }
    if (data.containsKey('last_received')) {
      context.handle(
          _lastReceivedMeta,
          lastReceived.isAcceptableOrUnknown(
              data['last_received'], _lastReceivedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => <GeneratedColumn>{};
  @override
  DbOlmSessions map(Map<String, dynamic> data, {String tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : null;
    return DbOlmSessions.fromData(data, _db, prefix: effectivePrefix);
  }

  @override
  OlmSessions createAlias(String alias) {
    return OlmSessions(_db, alias);
  }

  @override
  List<String> get customConstraints =>
      const ['UNIQUE(client_id, identity_key, session_id)'];
  @override
  bool get dontWriteConstraints => true;
}

class DbOutboundGroupSession extends DataClass
    implements Insertable<DbOutboundGroupSession> {
  final int clientId;
  final String roomId;
  final String pickle;
  final String deviceIds;
  final DateTime creationTime;
  final int sentMessages;
  DbOutboundGroupSession(
      {@required this.clientId,
      @required this.roomId,
      @required this.pickle,
      @required this.deviceIds,
      @required this.creationTime,
      @required this.sentMessages});
  factory DbOutboundGroupSession.fromData(
      Map<String, dynamic> data, GeneratedDatabase db,
      {String prefix}) {
    final effectivePrefix = prefix ?? '';
    final intType = db.typeSystem.forDartType<int>();
    final stringType = db.typeSystem.forDartType<String>();
    final dateTimeType = db.typeSystem.forDartType<DateTime>();
    return DbOutboundGroupSession(
      clientId:
          intType.mapFromDatabaseResponse(data['${effectivePrefix}client_id']),
      roomId:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}room_id']),
      pickle:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}pickle']),
      deviceIds: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}device_ids']),
      creationTime: dateTimeType
          .mapFromDatabaseResponse(data['${effectivePrefix}creation_time']),
      sentMessages: intType
          .mapFromDatabaseResponse(data['${effectivePrefix}sent_messages']),
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || clientId != null) {
      map['client_id'] = Variable<int>(clientId);
    }
    if (!nullToAbsent || roomId != null) {
      map['room_id'] = Variable<String>(roomId);
    }
    if (!nullToAbsent || pickle != null) {
      map['pickle'] = Variable<String>(pickle);
    }
    if (!nullToAbsent || deviceIds != null) {
      map['device_ids'] = Variable<String>(deviceIds);
    }
    if (!nullToAbsent || creationTime != null) {
      map['creation_time'] = Variable<DateTime>(creationTime);
    }
    if (!nullToAbsent || sentMessages != null) {
      map['sent_messages'] = Variable<int>(sentMessages);
    }
    return map;
  }

  factory DbOutboundGroupSession.fromJson(Map<String, dynamic> json,
      {ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return DbOutboundGroupSession(
      clientId: serializer.fromJson<int>(json['client_id']),
      roomId: serializer.fromJson<String>(json['room_id']),
      pickle: serializer.fromJson<String>(json['pickle']),
      deviceIds: serializer.fromJson<String>(json['device_ids']),
      creationTime: serializer.fromJson<DateTime>(json['creation_time']),
      sentMessages: serializer.fromJson<int>(json['sent_messages']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'client_id': serializer.toJson<int>(clientId),
      'room_id': serializer.toJson<String>(roomId),
      'pickle': serializer.toJson<String>(pickle),
      'device_ids': serializer.toJson<String>(deviceIds),
      'creation_time': serializer.toJson<DateTime>(creationTime),
      'sent_messages': serializer.toJson<int>(sentMessages),
    };
  }

  DbOutboundGroupSession copyWith(
          {int clientId,
          String roomId,
          String pickle,
          String deviceIds,
          DateTime creationTime,
          int sentMessages}) =>
      DbOutboundGroupSession(
        clientId: clientId ?? this.clientId,
        roomId: roomId ?? this.roomId,
        pickle: pickle ?? this.pickle,
        deviceIds: deviceIds ?? this.deviceIds,
        creationTime: creationTime ?? this.creationTime,
        sentMessages: sentMessages ?? this.sentMessages,
      );
  @override
  String toString() {
    return (StringBuffer('DbOutboundGroupSession(')
          ..write('clientId: $clientId, ')
          ..write('roomId: $roomId, ')
          ..write('pickle: $pickle, ')
          ..write('deviceIds: $deviceIds, ')
          ..write('creationTime: $creationTime, ')
          ..write('sentMessages: $sentMessages')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => $mrjf($mrjc(
      clientId.hashCode,
      $mrjc(
          roomId.hashCode,
          $mrjc(
              pickle.hashCode,
              $mrjc(deviceIds.hashCode,
                  $mrjc(creationTime.hashCode, sentMessages.hashCode))))));
  @override
  bool operator ==(dynamic other) =>
      identical(this, other) ||
      (other is DbOutboundGroupSession &&
          other.clientId == this.clientId &&
          other.roomId == this.roomId &&
          other.pickle == this.pickle &&
          other.deviceIds == this.deviceIds &&
          other.creationTime == this.creationTime &&
          other.sentMessages == this.sentMessages);
}

class OutboundGroupSessionsCompanion
    extends UpdateCompanion<DbOutboundGroupSession> {
  final Value<int> clientId;
  final Value<String> roomId;
  final Value<String> pickle;
  final Value<String> deviceIds;
  final Value<DateTime> creationTime;
  final Value<int> sentMessages;
  const OutboundGroupSessionsCompanion({
    this.clientId = const Value.absent(),
    this.roomId = const Value.absent(),
    this.pickle = const Value.absent(),
    this.deviceIds = const Value.absent(),
    this.creationTime = const Value.absent(),
    this.sentMessages = const Value.absent(),
  });
  OutboundGroupSessionsCompanion.insert({
    @required int clientId,
    @required String roomId,
    @required String pickle,
    @required String deviceIds,
    @required DateTime creationTime,
    this.sentMessages = const Value.absent(),
  })  : clientId = Value(clientId),
        roomId = Value(roomId),
        pickle = Value(pickle),
        deviceIds = Value(deviceIds),
        creationTime = Value(creationTime);
  static Insertable<DbOutboundGroupSession> custom({
    Expression<int> clientId,
    Expression<String> roomId,
    Expression<String> pickle,
    Expression<String> deviceIds,
    Expression<DateTime> creationTime,
    Expression<int> sentMessages,
  }) {
    return RawValuesInsertable({
      if (clientId != null) 'client_id': clientId,
      if (roomId != null) 'room_id': roomId,
      if (pickle != null) 'pickle': pickle,
      if (deviceIds != null) 'device_ids': deviceIds,
      if (creationTime != null) 'creation_time': creationTime,
      if (sentMessages != null) 'sent_messages': sentMessages,
    });
  }

  OutboundGroupSessionsCompanion copyWith(
      {Value<int> clientId,
      Value<String> roomId,
      Value<String> pickle,
      Value<String> deviceIds,
      Value<DateTime> creationTime,
      Value<int> sentMessages}) {
    return OutboundGroupSessionsCompanion(
      clientId: clientId ?? this.clientId,
      roomId: roomId ?? this.roomId,
      pickle: pickle ?? this.pickle,
      deviceIds: deviceIds ?? this.deviceIds,
      creationTime: creationTime ?? this.creationTime,
      sentMessages: sentMessages ?? this.sentMessages,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientId.present) {
      map['client_id'] = Variable<int>(clientId.value);
    }
    if (roomId.present) {
      map['room_id'] = Variable<String>(roomId.value);
    }
    if (pickle.present) {
      map['pickle'] = Variable<String>(pickle.value);
    }
    if (deviceIds.present) {
      map['device_ids'] = Variable<String>(deviceIds.value);
    }
    if (creationTime.present) {
      map['creation_time'] = Variable<DateTime>(creationTime.value);
    }
    if (sentMessages.present) {
      map['sent_messages'] = Variable<int>(sentMessages.value);
    }
    return map;
  }
}

class OutboundGroupSessions extends Table
    with TableInfo<OutboundGroupSessions, DbOutboundGroupSession> {
  final GeneratedDatabase _db;
  final String _alias;
  OutboundGroupSessions(this._db, [this._alias]);
  final VerificationMeta _clientIdMeta = const VerificationMeta('clientId');
  GeneratedIntColumn _clientId;
  GeneratedIntColumn get clientId => _clientId ??= _constructClientId();
  GeneratedIntColumn _constructClientId() {
    return GeneratedIntColumn('client_id', $tableName, false,
        $customConstraints: 'NOT NULL REFERENCES clients(client_id)');
  }

  final VerificationMeta _roomIdMeta = const VerificationMeta('roomId');
  GeneratedTextColumn _roomId;
  GeneratedTextColumn get roomId => _roomId ??= _constructRoomId();
  GeneratedTextColumn _constructRoomId() {
    return GeneratedTextColumn('room_id', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _pickleMeta = const VerificationMeta('pickle');
  GeneratedTextColumn _pickle;
  GeneratedTextColumn get pickle => _pickle ??= _constructPickle();
  GeneratedTextColumn _constructPickle() {
    return GeneratedTextColumn('pickle', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _deviceIdsMeta = const VerificationMeta('deviceIds');
  GeneratedTextColumn _deviceIds;
  GeneratedTextColumn get deviceIds => _deviceIds ??= _constructDeviceIds();
  GeneratedTextColumn _constructDeviceIds() {
    return GeneratedTextColumn('device_ids', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _creationTimeMeta =
      const VerificationMeta('creationTime');
  GeneratedDateTimeColumn _creationTime;
  GeneratedDateTimeColumn get creationTime =>
      _creationTime ??= _constructCreationTime();
  GeneratedDateTimeColumn _constructCreationTime() {
    return GeneratedDateTimeColumn('creation_time', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _sentMessagesMeta =
      const VerificationMeta('sentMessages');
  GeneratedIntColumn _sentMessages;
  GeneratedIntColumn get sentMessages =>
      _sentMessages ??= _constructSentMessages();
  GeneratedIntColumn _constructSentMessages() {
    return GeneratedIntColumn('sent_messages', $tableName, false,
        $customConstraints: 'NOT NULL DEFAULT \'0\'',
        defaultValue: const CustomExpression<int>('\'0\''));
  }

  @override
  List<GeneratedColumn> get $columns =>
      [clientId, roomId, pickle, deviceIds, creationTime, sentMessages];
  @override
  OutboundGroupSessions get asDslTable => this;
  @override
  String get $tableName => _alias ?? 'outbound_group_sessions';
  @override
  final String actualTableName = 'outbound_group_sessions';
  @override
  VerificationContext validateIntegrity(
      Insertable<DbOutboundGroupSession> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id'], _clientIdMeta));
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('room_id')) {
      context.handle(_roomIdMeta,
          roomId.isAcceptableOrUnknown(data['room_id'], _roomIdMeta));
    } else if (isInserting) {
      context.missing(_roomIdMeta);
    }
    if (data.containsKey('pickle')) {
      context.handle(_pickleMeta,
          pickle.isAcceptableOrUnknown(data['pickle'], _pickleMeta));
    } else if (isInserting) {
      context.missing(_pickleMeta);
    }
    if (data.containsKey('device_ids')) {
      context.handle(_deviceIdsMeta,
          deviceIds.isAcceptableOrUnknown(data['device_ids'], _deviceIdsMeta));
    } else if (isInserting) {
      context.missing(_deviceIdsMeta);
    }
    if (data.containsKey('creation_time')) {
      context.handle(
          _creationTimeMeta,
          creationTime.isAcceptableOrUnknown(
              data['creation_time'], _creationTimeMeta));
    } else if (isInserting) {
      context.missing(_creationTimeMeta);
    }
    if (data.containsKey('sent_messages')) {
      context.handle(
          _sentMessagesMeta,
          sentMessages.isAcceptableOrUnknown(
              data['sent_messages'], _sentMessagesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => <GeneratedColumn>{};
  @override
  DbOutboundGroupSession map(Map<String, dynamic> data, {String tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : null;
    return DbOutboundGroupSession.fromData(data, _db, prefix: effectivePrefix);
  }

  @override
  OutboundGroupSessions createAlias(String alias) {
    return OutboundGroupSessions(_db, alias);
  }

  @override
  List<String> get customConstraints => const ['UNIQUE(client_id, room_id)'];
  @override
  bool get dontWriteConstraints => true;
}

class DbInboundGroupSession extends DataClass
    implements Insertable<DbInboundGroupSession> {
  final int clientId;
  final String roomId;
  final String sessionId;
  final String pickle;
  final String content;
  final String indexes;
  DbInboundGroupSession(
      {@required this.clientId,
      @required this.roomId,
      @required this.sessionId,
      @required this.pickle,
      this.content,
      this.indexes});
  factory DbInboundGroupSession.fromData(
      Map<String, dynamic> data, GeneratedDatabase db,
      {String prefix}) {
    final effectivePrefix = prefix ?? '';
    final intType = db.typeSystem.forDartType<int>();
    final stringType = db.typeSystem.forDartType<String>();
    return DbInboundGroupSession(
      clientId:
          intType.mapFromDatabaseResponse(data['${effectivePrefix}client_id']),
      roomId:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}room_id']),
      sessionId: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}session_id']),
      pickle:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}pickle']),
      content:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}content']),
      indexes:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}indexes']),
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || clientId != null) {
      map['client_id'] = Variable<int>(clientId);
    }
    if (!nullToAbsent || roomId != null) {
      map['room_id'] = Variable<String>(roomId);
    }
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    if (!nullToAbsent || pickle != null) {
      map['pickle'] = Variable<String>(pickle);
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || indexes != null) {
      map['indexes'] = Variable<String>(indexes);
    }
    return map;
  }

  factory DbInboundGroupSession.fromJson(Map<String, dynamic> json,
      {ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return DbInboundGroupSession(
      clientId: serializer.fromJson<int>(json['client_id']),
      roomId: serializer.fromJson<String>(json['room_id']),
      sessionId: serializer.fromJson<String>(json['session_id']),
      pickle: serializer.fromJson<String>(json['pickle']),
      content: serializer.fromJson<String>(json['content']),
      indexes: serializer.fromJson<String>(json['indexes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'client_id': serializer.toJson<int>(clientId),
      'room_id': serializer.toJson<String>(roomId),
      'session_id': serializer.toJson<String>(sessionId),
      'pickle': serializer.toJson<String>(pickle),
      'content': serializer.toJson<String>(content),
      'indexes': serializer.toJson<String>(indexes),
    };
  }

  DbInboundGroupSession copyWith(
          {int clientId,
          String roomId,
          String sessionId,
          String pickle,
          String content,
          String indexes}) =>
      DbInboundGroupSession(
        clientId: clientId ?? this.clientId,
        roomId: roomId ?? this.roomId,
        sessionId: sessionId ?? this.sessionId,
        pickle: pickle ?? this.pickle,
        content: content ?? this.content,
        indexes: indexes ?? this.indexes,
      );
  @override
  String toString() {
    return (StringBuffer('DbInboundGroupSession(')
          ..write('clientId: $clientId, ')
          ..write('roomId: $roomId, ')
          ..write('sessionId: $sessionId, ')
          ..write('pickle: $pickle, ')
          ..write('content: $content, ')
          ..write('indexes: $indexes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => $mrjf($mrjc(
      clientId.hashCode,
      $mrjc(
          roomId.hashCode,
          $mrjc(
              sessionId.hashCode,
              $mrjc(pickle.hashCode,
                  $mrjc(content.hashCode, indexes.hashCode))))));
  @override
  bool operator ==(dynamic other) =>
      identical(this, other) ||
      (other is DbInboundGroupSession &&
          other.clientId == this.clientId &&
          other.roomId == this.roomId &&
          other.sessionId == this.sessionId &&
          other.pickle == this.pickle &&
          other.content == this.content &&
          other.indexes == this.indexes);
}

class InboundGroupSessionsCompanion
    extends UpdateCompanion<DbInboundGroupSession> {
  final Value<int> clientId;
  final Value<String> roomId;
  final Value<String> sessionId;
  final Value<String> pickle;
  final Value<String> content;
  final Value<String> indexes;
  const InboundGroupSessionsCompanion({
    this.clientId = const Value.absent(),
    this.roomId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.pickle = const Value.absent(),
    this.content = const Value.absent(),
    this.indexes = const Value.absent(),
  });
  InboundGroupSessionsCompanion.insert({
    @required int clientId,
    @required String roomId,
    @required String sessionId,
    @required String pickle,
    this.content = const Value.absent(),
    this.indexes = const Value.absent(),
  })  : clientId = Value(clientId),
        roomId = Value(roomId),
        sessionId = Value(sessionId),
        pickle = Value(pickle);
  static Insertable<DbInboundGroupSession> custom({
    Expression<int> clientId,
    Expression<String> roomId,
    Expression<String> sessionId,
    Expression<String> pickle,
    Expression<String> content,
    Expression<String> indexes,
  }) {
    return RawValuesInsertable({
      if (clientId != null) 'client_id': clientId,
      if (roomId != null) 'room_id': roomId,
      if (sessionId != null) 'session_id': sessionId,
      if (pickle != null) 'pickle': pickle,
      if (content != null) 'content': content,
      if (indexes != null) 'indexes': indexes,
    });
  }

  InboundGroupSessionsCompanion copyWith(
      {Value<int> clientId,
      Value<String> roomId,
      Value<String> sessionId,
      Value<String> pickle,
      Value<String> content,
      Value<String> indexes}) {
    return InboundGroupSessionsCompanion(
      clientId: clientId ?? this.clientId,
      roomId: roomId ?? this.roomId,
      sessionId: sessionId ?? this.sessionId,
      pickle: pickle ?? this.pickle,
      content: content ?? this.content,
      indexes: indexes ?? this.indexes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientId.present) {
      map['client_id'] = Variable<int>(clientId.value);
    }
    if (roomId.present) {
      map['room_id'] = Variable<String>(roomId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (pickle.present) {
      map['pickle'] = Variable<String>(pickle.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (indexes.present) {
      map['indexes'] = Variable<String>(indexes.value);
    }
    return map;
  }
}

class InboundGroupSessions extends Table
    with TableInfo<InboundGroupSessions, DbInboundGroupSession> {
  final GeneratedDatabase _db;
  final String _alias;
  InboundGroupSessions(this._db, [this._alias]);
  final VerificationMeta _clientIdMeta = const VerificationMeta('clientId');
  GeneratedIntColumn _clientId;
  GeneratedIntColumn get clientId => _clientId ??= _constructClientId();
  GeneratedIntColumn _constructClientId() {
    return GeneratedIntColumn('client_id', $tableName, false,
        $customConstraints: 'NOT NULL REFERENCES clients(client_id)');
  }

  final VerificationMeta _roomIdMeta = const VerificationMeta('roomId');
  GeneratedTextColumn _roomId;
  GeneratedTextColumn get roomId => _roomId ??= _constructRoomId();
  GeneratedTextColumn _constructRoomId() {
    return GeneratedTextColumn('room_id', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _sessionIdMeta = const VerificationMeta('sessionId');
  GeneratedTextColumn _sessionId;
  GeneratedTextColumn get sessionId => _sessionId ??= _constructSessionId();
  GeneratedTextColumn _constructSessionId() {
    return GeneratedTextColumn('session_id', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _pickleMeta = const VerificationMeta('pickle');
  GeneratedTextColumn _pickle;
  GeneratedTextColumn get pickle => _pickle ??= _constructPickle();
  GeneratedTextColumn _constructPickle() {
    return GeneratedTextColumn('pickle', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _contentMeta = const VerificationMeta('content');
  GeneratedTextColumn _content;
  GeneratedTextColumn get content => _content ??= _constructContent();
  GeneratedTextColumn _constructContent() {
    return GeneratedTextColumn('content', $tableName, true,
        $customConstraints: '');
  }

  final VerificationMeta _indexesMeta = const VerificationMeta('indexes');
  GeneratedTextColumn _indexes;
  GeneratedTextColumn get indexes => _indexes ??= _constructIndexes();
  GeneratedTextColumn _constructIndexes() {
    return GeneratedTextColumn('indexes', $tableName, true,
        $customConstraints: '');
  }

  @override
  List<GeneratedColumn> get $columns =>
      [clientId, roomId, sessionId, pickle, content, indexes];
  @override
  InboundGroupSessions get asDslTable => this;
  @override
  String get $tableName => _alias ?? 'inbound_group_sessions';
  @override
  final String actualTableName = 'inbound_group_sessions';
  @override
  VerificationContext validateIntegrity(
      Insertable<DbInboundGroupSession> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id'], _clientIdMeta));
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('room_id')) {
      context.handle(_roomIdMeta,
          roomId.isAcceptableOrUnknown(data['room_id'], _roomIdMeta));
    } else if (isInserting) {
      context.missing(_roomIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id'], _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('pickle')) {
      context.handle(_pickleMeta,
          pickle.isAcceptableOrUnknown(data['pickle'], _pickleMeta));
    } else if (isInserting) {
      context.missing(_pickleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content'], _contentMeta));
    }
    if (data.containsKey('indexes')) {
      context.handle(_indexesMeta,
          indexes.isAcceptableOrUnknown(data['indexes'], _indexesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => <GeneratedColumn>{};
  @override
  DbInboundGroupSession map(Map<String, dynamic> data, {String tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : null;
    return DbInboundGroupSession.fromData(data, _db, prefix: effectivePrefix);
  }

  @override
  InboundGroupSessions createAlias(String alias) {
    return InboundGroupSessions(_db, alias);
  }

  @override
  List<String> get customConstraints =>
      const ['UNIQUE(client_id, room_id, session_id)'];
  @override
  bool get dontWriteConstraints => true;
}

class DbRoom extends DataClass implements Insertable<DbRoom> {
  final int clientId;
  final String roomId;
  final String membership;
  final int highlightCount;
  final int notificationCount;
  final String prevBatch;
  final int joinedMemberCount;
  final int invitedMemberCount;
  final double newestSortOrder;
  final double oldestSortOrder;
  final String heroes;
  DbRoom(
      {@required this.clientId,
      @required this.roomId,
      @required this.membership,
      @required this.highlightCount,
      @required this.notificationCount,
      this.prevBatch,
      @required this.joinedMemberCount,
      @required this.invitedMemberCount,
      @required this.newestSortOrder,
      @required this.oldestSortOrder,
      this.heroes});
  factory DbRoom.fromData(Map<String, dynamic> data, GeneratedDatabase db,
      {String prefix}) {
    final effectivePrefix = prefix ?? '';
    final intType = db.typeSystem.forDartType<int>();
    final stringType = db.typeSystem.forDartType<String>();
    final doubleType = db.typeSystem.forDartType<double>();
    return DbRoom(
      clientId:
          intType.mapFromDatabaseResponse(data['${effectivePrefix}client_id']),
      roomId:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}room_id']),
      membership: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}membership']),
      highlightCount: intType
          .mapFromDatabaseResponse(data['${effectivePrefix}highlight_count']),
      notificationCount: intType.mapFromDatabaseResponse(
          data['${effectivePrefix}notification_count']),
      prevBatch: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}prev_batch']),
      joinedMemberCount: intType.mapFromDatabaseResponse(
          data['${effectivePrefix}joined_member_count']),
      invitedMemberCount: intType.mapFromDatabaseResponse(
          data['${effectivePrefix}invited_member_count']),
      newestSortOrder: doubleType
          .mapFromDatabaseResponse(data['${effectivePrefix}newest_sort_order']),
      oldestSortOrder: doubleType
          .mapFromDatabaseResponse(data['${effectivePrefix}oldest_sort_order']),
      heroes:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}heroes']),
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || clientId != null) {
      map['client_id'] = Variable<int>(clientId);
    }
    if (!nullToAbsent || roomId != null) {
      map['room_id'] = Variable<String>(roomId);
    }
    if (!nullToAbsent || membership != null) {
      map['membership'] = Variable<String>(membership);
    }
    if (!nullToAbsent || highlightCount != null) {
      map['highlight_count'] = Variable<int>(highlightCount);
    }
    if (!nullToAbsent || notificationCount != null) {
      map['notification_count'] = Variable<int>(notificationCount);
    }
    if (!nullToAbsent || prevBatch != null) {
      map['prev_batch'] = Variable<String>(prevBatch);
    }
    if (!nullToAbsent || joinedMemberCount != null) {
      map['joined_member_count'] = Variable<int>(joinedMemberCount);
    }
    if (!nullToAbsent || invitedMemberCount != null) {
      map['invited_member_count'] = Variable<int>(invitedMemberCount);
    }
    if (!nullToAbsent || newestSortOrder != null) {
      map['newest_sort_order'] = Variable<double>(newestSortOrder);
    }
    if (!nullToAbsent || oldestSortOrder != null) {
      map['oldest_sort_order'] = Variable<double>(oldestSortOrder);
    }
    if (!nullToAbsent || heroes != null) {
      map['heroes'] = Variable<String>(heroes);
    }
    return map;
  }

  factory DbRoom.fromJson(Map<String, dynamic> json,
      {ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return DbRoom(
      clientId: serializer.fromJson<int>(json['client_id']),
      roomId: serializer.fromJson<String>(json['room_id']),
      membership: serializer.fromJson<String>(json['membership']),
      highlightCount: serializer.fromJson<int>(json['highlight_count']),
      notificationCount: serializer.fromJson<int>(json['notification_count']),
      prevBatch: serializer.fromJson<String>(json['prev_batch']),
      joinedMemberCount: serializer.fromJson<int>(json['joined_member_count']),
      invitedMemberCount:
          serializer.fromJson<int>(json['invited_member_count']),
      newestSortOrder: serializer.fromJson<double>(json['newest_sort_order']),
      oldestSortOrder: serializer.fromJson<double>(json['oldest_sort_order']),
      heroes: serializer.fromJson<String>(json['heroes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'client_id': serializer.toJson<int>(clientId),
      'room_id': serializer.toJson<String>(roomId),
      'membership': serializer.toJson<String>(membership),
      'highlight_count': serializer.toJson<int>(highlightCount),
      'notification_count': serializer.toJson<int>(notificationCount),
      'prev_batch': serializer.toJson<String>(prevBatch),
      'joined_member_count': serializer.toJson<int>(joinedMemberCount),
      'invited_member_count': serializer.toJson<int>(invitedMemberCount),
      'newest_sort_order': serializer.toJson<double>(newestSortOrder),
      'oldest_sort_order': serializer.toJson<double>(oldestSortOrder),
      'heroes': serializer.toJson<String>(heroes),
    };
  }

  DbRoom copyWith(
          {int clientId,
          String roomId,
          String membership,
          int highlightCount,
          int notificationCount,
          String prevBatch,
          int joinedMemberCount,
          int invitedMemberCount,
          double newestSortOrder,
          double oldestSortOrder,
          String heroes}) =>
      DbRoom(
        clientId: clientId ?? this.clientId,
        roomId: roomId ?? this.roomId,
        membership: membership ?? this.membership,
        highlightCount: highlightCount ?? this.highlightCount,
        notificationCount: notificationCount ?? this.notificationCount,
        prevBatch: prevBatch ?? this.prevBatch,
        joinedMemberCount: joinedMemberCount ?? this.joinedMemberCount,
        invitedMemberCount: invitedMemberCount ?? this.invitedMemberCount,
        newestSortOrder: newestSortOrder ?? this.newestSortOrder,
        oldestSortOrder: oldestSortOrder ?? this.oldestSortOrder,
        heroes: heroes ?? this.heroes,
      );
  @override
  String toString() {
    return (StringBuffer('DbRoom(')
          ..write('clientId: $clientId, ')
          ..write('roomId: $roomId, ')
          ..write('membership: $membership, ')
          ..write('highlightCount: $highlightCount, ')
          ..write('notificationCount: $notificationCount, ')
          ..write('prevBatch: $prevBatch, ')
          ..write('joinedMemberCount: $joinedMemberCount, ')
          ..write('invitedMemberCount: $invitedMemberCount, ')
          ..write('newestSortOrder: $newestSortOrder, ')
          ..write('oldestSortOrder: $oldestSortOrder, ')
          ..write('heroes: $heroes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => $mrjf($mrjc(
      clientId.hashCode,
      $mrjc(
          roomId.hashCode,
          $mrjc(
              membership.hashCode,
              $mrjc(
                  highlightCount.hashCode,
                  $mrjc(
                      notificationCount.hashCode,
                      $mrjc(
                          prevBatch.hashCode,
                          $mrjc(
                              joinedMemberCount.hashCode,
                              $mrjc(
                                  invitedMemberCount.hashCode,
                                  $mrjc(
                                      newestSortOrder.hashCode,
                                      $mrjc(oldestSortOrder.hashCode,
                                          heroes.hashCode)))))))))));
  @override
  bool operator ==(dynamic other) =>
      identical(this, other) ||
      (other is DbRoom &&
          other.clientId == this.clientId &&
          other.roomId == this.roomId &&
          other.membership == this.membership &&
          other.highlightCount == this.highlightCount &&
          other.notificationCount == this.notificationCount &&
          other.prevBatch == this.prevBatch &&
          other.joinedMemberCount == this.joinedMemberCount &&
          other.invitedMemberCount == this.invitedMemberCount &&
          other.newestSortOrder == this.newestSortOrder &&
          other.oldestSortOrder == this.oldestSortOrder &&
          other.heroes == this.heroes);
}

class RoomsCompanion extends UpdateCompanion<DbRoom> {
  final Value<int> clientId;
  final Value<String> roomId;
  final Value<String> membership;
  final Value<int> highlightCount;
  final Value<int> notificationCount;
  final Value<String> prevBatch;
  final Value<int> joinedMemberCount;
  final Value<int> invitedMemberCount;
  final Value<double> newestSortOrder;
  final Value<double> oldestSortOrder;
  final Value<String> heroes;
  const RoomsCompanion({
    this.clientId = const Value.absent(),
    this.roomId = const Value.absent(),
    this.membership = const Value.absent(),
    this.highlightCount = const Value.absent(),
    this.notificationCount = const Value.absent(),
    this.prevBatch = const Value.absent(),
    this.joinedMemberCount = const Value.absent(),
    this.invitedMemberCount = const Value.absent(),
    this.newestSortOrder = const Value.absent(),
    this.oldestSortOrder = const Value.absent(),
    this.heroes = const Value.absent(),
  });
  RoomsCompanion.insert({
    @required int clientId,
    @required String roomId,
    @required String membership,
    this.highlightCount = const Value.absent(),
    this.notificationCount = const Value.absent(),
    this.prevBatch = const Value.absent(),
    this.joinedMemberCount = const Value.absent(),
    this.invitedMemberCount = const Value.absent(),
    this.newestSortOrder = const Value.absent(),
    this.oldestSortOrder = const Value.absent(),
    this.heroes = const Value.absent(),
  })  : clientId = Value(clientId),
        roomId = Value(roomId),
        membership = Value(membership);
  static Insertable<DbRoom> custom({
    Expression<int> clientId,
    Expression<String> roomId,
    Expression<String> membership,
    Expression<int> highlightCount,
    Expression<int> notificationCount,
    Expression<String> prevBatch,
    Expression<int> joinedMemberCount,
    Expression<int> invitedMemberCount,
    Expression<double> newestSortOrder,
    Expression<double> oldestSortOrder,
    Expression<String> heroes,
  }) {
    return RawValuesInsertable({
      if (clientId != null) 'client_id': clientId,
      if (roomId != null) 'room_id': roomId,
      if (membership != null) 'membership': membership,
      if (highlightCount != null) 'highlight_count': highlightCount,
      if (notificationCount != null) 'notification_count': notificationCount,
      if (prevBatch != null) 'prev_batch': prevBatch,
      if (joinedMemberCount != null) 'joined_member_count': joinedMemberCount,
      if (invitedMemberCount != null)
        'invited_member_count': invitedMemberCount,
      if (newestSortOrder != null) 'newest_sort_order': newestSortOrder,
      if (oldestSortOrder != null) 'oldest_sort_order': oldestSortOrder,
      if (heroes != null) 'heroes': heroes,
    });
  }

  RoomsCompanion copyWith(
      {Value<int> clientId,
      Value<String> roomId,
      Value<String> membership,
      Value<int> highlightCount,
      Value<int> notificationCount,
      Value<String> prevBatch,
      Value<int> joinedMemberCount,
      Value<int> invitedMemberCount,
      Value<double> newestSortOrder,
      Value<double> oldestSortOrder,
      Value<String> heroes}) {
    return RoomsCompanion(
      clientId: clientId ?? this.clientId,
      roomId: roomId ?? this.roomId,
      membership: membership ?? this.membership,
      highlightCount: highlightCount ?? this.highlightCount,
      notificationCount: notificationCount ?? this.notificationCount,
      prevBatch: prevBatch ?? this.prevBatch,
      joinedMemberCount: joinedMemberCount ?? this.joinedMemberCount,
      invitedMemberCount: invitedMemberCount ?? this.invitedMemberCount,
      newestSortOrder: newestSortOrder ?? this.newestSortOrder,
      oldestSortOrder: oldestSortOrder ?? this.oldestSortOrder,
      heroes: heroes ?? this.heroes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientId.present) {
      map['client_id'] = Variable<int>(clientId.value);
    }
    if (roomId.present) {
      map['room_id'] = Variable<String>(roomId.value);
    }
    if (membership.present) {
      map['membership'] = Variable<String>(membership.value);
    }
    if (highlightCount.present) {
      map['highlight_count'] = Variable<int>(highlightCount.value);
    }
    if (notificationCount.present) {
      map['notification_count'] = Variable<int>(notificationCount.value);
    }
    if (prevBatch.present) {
      map['prev_batch'] = Variable<String>(prevBatch.value);
    }
    if (joinedMemberCount.present) {
      map['joined_member_count'] = Variable<int>(joinedMemberCount.value);
    }
    if (invitedMemberCount.present) {
      map['invited_member_count'] = Variable<int>(invitedMemberCount.value);
    }
    if (newestSortOrder.present) {
      map['newest_sort_order'] = Variable<double>(newestSortOrder.value);
    }
    if (oldestSortOrder.present) {
      map['oldest_sort_order'] = Variable<double>(oldestSortOrder.value);
    }
    if (heroes.present) {
      map['heroes'] = Variable<String>(heroes.value);
    }
    return map;
  }
}

class Rooms extends Table with TableInfo<Rooms, DbRoom> {
  final GeneratedDatabase _db;
  final String _alias;
  Rooms(this._db, [this._alias]);
  final VerificationMeta _clientIdMeta = const VerificationMeta('clientId');
  GeneratedIntColumn _clientId;
  GeneratedIntColumn get clientId => _clientId ??= _constructClientId();
  GeneratedIntColumn _constructClientId() {
    return GeneratedIntColumn('client_id', $tableName, false,
        $customConstraints: 'NOT NULL REFERENCES clients(client_id)');
  }

  final VerificationMeta _roomIdMeta = const VerificationMeta('roomId');
  GeneratedTextColumn _roomId;
  GeneratedTextColumn get roomId => _roomId ??= _constructRoomId();
  GeneratedTextColumn _constructRoomId() {
    return GeneratedTextColumn('room_id', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _membershipMeta = const VerificationMeta('membership');
  GeneratedTextColumn _membership;
  GeneratedTextColumn get membership => _membership ??= _constructMembership();
  GeneratedTextColumn _constructMembership() {
    return GeneratedTextColumn('membership', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _highlightCountMeta =
      const VerificationMeta('highlightCount');
  GeneratedIntColumn _highlightCount;
  GeneratedIntColumn get highlightCount =>
      _highlightCount ??= _constructHighlightCount();
  GeneratedIntColumn _constructHighlightCount() {
    return GeneratedIntColumn('highlight_count', $tableName, false,
        $customConstraints: 'NOT NULL DEFAULT \'0\'',
        defaultValue: const CustomExpression<int>('\'0\''));
  }

  final VerificationMeta _notificationCountMeta =
      const VerificationMeta('notificationCount');
  GeneratedIntColumn _notificationCount;
  GeneratedIntColumn get notificationCount =>
      _notificationCount ??= _constructNotificationCount();
  GeneratedIntColumn _constructNotificationCount() {
    return GeneratedIntColumn('notification_count', $tableName, false,
        $customConstraints: 'NOT NULL DEFAULT \'0\'',
        defaultValue: const CustomExpression<int>('\'0\''));
  }

  final VerificationMeta _prevBatchMeta = const VerificationMeta('prevBatch');
  GeneratedTextColumn _prevBatch;
  GeneratedTextColumn get prevBatch => _prevBatch ??= _constructPrevBatch();
  GeneratedTextColumn _constructPrevBatch() {
    return GeneratedTextColumn('prev_batch', $tableName, true,
        $customConstraints: 'DEFAULT \'\'',
        defaultValue: const CustomExpression<String>('\'\''));
  }

  final VerificationMeta _joinedMemberCountMeta =
      const VerificationMeta('joinedMemberCount');
  GeneratedIntColumn _joinedMemberCount;
  GeneratedIntColumn get joinedMemberCount =>
      _joinedMemberCount ??= _constructJoinedMemberCount();
  GeneratedIntColumn _constructJoinedMemberCount() {
    return GeneratedIntColumn('joined_member_count', $tableName, false,
        $customConstraints: 'NOT NULL DEFAULT \'0\'',
        defaultValue: const CustomExpression<int>('\'0\''));
  }

  final VerificationMeta _invitedMemberCountMeta =
      const VerificationMeta('invitedMemberCount');
  GeneratedIntColumn _invitedMemberCount;
  GeneratedIntColumn get invitedMemberCount =>
      _invitedMemberCount ??= _constructInvitedMemberCount();
  GeneratedIntColumn _constructInvitedMemberCount() {
    return GeneratedIntColumn('invited_member_count', $tableName, false,
        $customConstraints: 'NOT NULL DEFAULT \'0\'',
        defaultValue: const CustomExpression<int>('\'0\''));
  }

  final VerificationMeta _newestSortOrderMeta =
      const VerificationMeta('newestSortOrder');
  GeneratedRealColumn _newestSortOrder;
  GeneratedRealColumn get newestSortOrder =>
      _newestSortOrder ??= _constructNewestSortOrder();
  GeneratedRealColumn _constructNewestSortOrder() {
    return GeneratedRealColumn('newest_sort_order', $tableName, false,
        $customConstraints: 'NOT NULL DEFAULT \'0\'',
        defaultValue: const CustomExpression<double>('\'0\''));
  }

  final VerificationMeta _oldestSortOrderMeta =
      const VerificationMeta('oldestSortOrder');
  GeneratedRealColumn _oldestSortOrder;
  GeneratedRealColumn get oldestSortOrder =>
      _oldestSortOrder ??= _constructOldestSortOrder();
  GeneratedRealColumn _constructOldestSortOrder() {
    return GeneratedRealColumn('oldest_sort_order', $tableName, false,
        $customConstraints: 'NOT NULL DEFAULT \'0\'',
        defaultValue: const CustomExpression<double>('\'0\''));
  }

  final VerificationMeta _heroesMeta = const VerificationMeta('heroes');
  GeneratedTextColumn _heroes;
  GeneratedTextColumn get heroes => _heroes ??= _constructHeroes();
  GeneratedTextColumn _constructHeroes() {
    return GeneratedTextColumn('heroes', $tableName, true,
        $customConstraints: 'DEFAULT \'\'',
        defaultValue: const CustomExpression<String>('\'\''));
  }

  @override
  List<GeneratedColumn> get $columns => [
        clientId,
        roomId,
        membership,
        highlightCount,
        notificationCount,
        prevBatch,
        joinedMemberCount,
        invitedMemberCount,
        newestSortOrder,
        oldestSortOrder,
        heroes
      ];
  @override
  Rooms get asDslTable => this;
  @override
  String get $tableName => _alias ?? 'rooms';
  @override
  final String actualTableName = 'rooms';
  @override
  VerificationContext validateIntegrity(Insertable<DbRoom> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id'], _clientIdMeta));
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('room_id')) {
      context.handle(_roomIdMeta,
          roomId.isAcceptableOrUnknown(data['room_id'], _roomIdMeta));
    } else if (isInserting) {
      context.missing(_roomIdMeta);
    }
    if (data.containsKey('membership')) {
      context.handle(
          _membershipMeta,
          membership.isAcceptableOrUnknown(
              data['membership'], _membershipMeta));
    } else if (isInserting) {
      context.missing(_membershipMeta);
    }
    if (data.containsKey('highlight_count')) {
      context.handle(
          _highlightCountMeta,
          highlightCount.isAcceptableOrUnknown(
              data['highlight_count'], _highlightCountMeta));
    }
    if (data.containsKey('notification_count')) {
      context.handle(
          _notificationCountMeta,
          notificationCount.isAcceptableOrUnknown(
              data['notification_count'], _notificationCountMeta));
    }
    if (data.containsKey('prev_batch')) {
      context.handle(_prevBatchMeta,
          prevBatch.isAcceptableOrUnknown(data['prev_batch'], _prevBatchMeta));
    }
    if (data.containsKey('joined_member_count')) {
      context.handle(
          _joinedMemberCountMeta,
          joinedMemberCount.isAcceptableOrUnknown(
              data['joined_member_count'], _joinedMemberCountMeta));
    }
    if (data.containsKey('invited_member_count')) {
      context.handle(
          _invitedMemberCountMeta,
          invitedMemberCount.isAcceptableOrUnknown(
              data['invited_member_count'], _invitedMemberCountMeta));
    }
    if (data.containsKey('newest_sort_order')) {
      context.handle(
          _newestSortOrderMeta,
          newestSortOrder.isAcceptableOrUnknown(
              data['newest_sort_order'], _newestSortOrderMeta));
    }
    if (data.containsKey('oldest_sort_order')) {
      context.handle(
          _oldestSortOrderMeta,
          oldestSortOrder.isAcceptableOrUnknown(
              data['oldest_sort_order'], _oldestSortOrderMeta));
    }
    if (data.containsKey('heroes')) {
      context.handle(_heroesMeta,
          heroes.isAcceptableOrUnknown(data['heroes'], _heroesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => <GeneratedColumn>{};
  @override
  DbRoom map(Map<String, dynamic> data, {String tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : null;
    return DbRoom.fromData(data, _db, prefix: effectivePrefix);
  }

  @override
  Rooms createAlias(String alias) {
    return Rooms(_db, alias);
  }

  @override
  List<String> get customConstraints => const ['UNIQUE(client_id, room_id)'];
  @override
  bool get dontWriteConstraints => true;
}

class DbEvent extends DataClass implements Insertable<DbEvent> {
  final int clientId;
  final String eventId;
  final String roomId;
  final double sortOrder;
  final DateTime originServerTs;
  final String sender;
  final String type;
  final String unsigned;
  final String content;
  final String prevContent;
  final String stateKey;
  final int status;
  DbEvent(
      {@required this.clientId,
      @required this.eventId,
      @required this.roomId,
      @required this.sortOrder,
      @required this.originServerTs,
      @required this.sender,
      @required this.type,
      this.unsigned,
      this.content,
      this.prevContent,
      this.stateKey,
      this.status});
  factory DbEvent.fromData(Map<String, dynamic> data, GeneratedDatabase db,
      {String prefix}) {
    final effectivePrefix = prefix ?? '';
    final intType = db.typeSystem.forDartType<int>();
    final stringType = db.typeSystem.forDartType<String>();
    final doubleType = db.typeSystem.forDartType<double>();
    final dateTimeType = db.typeSystem.forDartType<DateTime>();
    return DbEvent(
      clientId:
          intType.mapFromDatabaseResponse(data['${effectivePrefix}client_id']),
      eventId: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}event_id']),
      roomId:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}room_id']),
      sortOrder: doubleType
          .mapFromDatabaseResponse(data['${effectivePrefix}sort_order']),
      originServerTs: dateTimeType
          .mapFromDatabaseResponse(data['${effectivePrefix}origin_server_ts']),
      sender:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}sender']),
      type: stringType.mapFromDatabaseResponse(data['${effectivePrefix}type']),
      unsigned: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}unsigned']),
      content:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}content']),
      prevContent: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}prev_content']),
      stateKey: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}state_key']),
      status: intType.mapFromDatabaseResponse(data['${effectivePrefix}status']),
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || clientId != null) {
      map['client_id'] = Variable<int>(clientId);
    }
    if (!nullToAbsent || eventId != null) {
      map['event_id'] = Variable<String>(eventId);
    }
    if (!nullToAbsent || roomId != null) {
      map['room_id'] = Variable<String>(roomId);
    }
    if (!nullToAbsent || sortOrder != null) {
      map['sort_order'] = Variable<double>(sortOrder);
    }
    if (!nullToAbsent || originServerTs != null) {
      map['origin_server_ts'] = Variable<DateTime>(originServerTs);
    }
    if (!nullToAbsent || sender != null) {
      map['sender'] = Variable<String>(sender);
    }
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    if (!nullToAbsent || unsigned != null) {
      map['unsigned'] = Variable<String>(unsigned);
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || prevContent != null) {
      map['prev_content'] = Variable<String>(prevContent);
    }
    if (!nullToAbsent || stateKey != null) {
      map['state_key'] = Variable<String>(stateKey);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<int>(status);
    }
    return map;
  }

  factory DbEvent.fromJson(Map<String, dynamic> json,
      {ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return DbEvent(
      clientId: serializer.fromJson<int>(json['client_id']),
      eventId: serializer.fromJson<String>(json['event_id']),
      roomId: serializer.fromJson<String>(json['room_id']),
      sortOrder: serializer.fromJson<double>(json['sort_order']),
      originServerTs: serializer.fromJson<DateTime>(json['origin_server_ts']),
      sender: serializer.fromJson<String>(json['sender']),
      type: serializer.fromJson<String>(json['type']),
      unsigned: serializer.fromJson<String>(json['unsigned']),
      content: serializer.fromJson<String>(json['content']),
      prevContent: serializer.fromJson<String>(json['prev_content']),
      stateKey: serializer.fromJson<String>(json['state_key']),
      status: serializer.fromJson<int>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'client_id': serializer.toJson<int>(clientId),
      'event_id': serializer.toJson<String>(eventId),
      'room_id': serializer.toJson<String>(roomId),
      'sort_order': serializer.toJson<double>(sortOrder),
      'origin_server_ts': serializer.toJson<DateTime>(originServerTs),
      'sender': serializer.toJson<String>(sender),
      'type': serializer.toJson<String>(type),
      'unsigned': serializer.toJson<String>(unsigned),
      'content': serializer.toJson<String>(content),
      'prev_content': serializer.toJson<String>(prevContent),
      'state_key': serializer.toJson<String>(stateKey),
      'status': serializer.toJson<int>(status),
    };
  }

  DbEvent copyWith(
          {int clientId,
          String eventId,
          String roomId,
          double sortOrder,
          DateTime originServerTs,
          String sender,
          String type,
          String unsigned,
          String content,
          String prevContent,
          String stateKey,
          int status}) =>
      DbEvent(
        clientId: clientId ?? this.clientId,
        eventId: eventId ?? this.eventId,
        roomId: roomId ?? this.roomId,
        sortOrder: sortOrder ?? this.sortOrder,
        originServerTs: originServerTs ?? this.originServerTs,
        sender: sender ?? this.sender,
        type: type ?? this.type,
        unsigned: unsigned ?? this.unsigned,
        content: content ?? this.content,
        prevContent: prevContent ?? this.prevContent,
        stateKey: stateKey ?? this.stateKey,
        status: status ?? this.status,
      );
  @override
  String toString() {
    return (StringBuffer('DbEvent(')
          ..write('clientId: $clientId, ')
          ..write('eventId: $eventId, ')
          ..write('roomId: $roomId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('originServerTs: $originServerTs, ')
          ..write('sender: $sender, ')
          ..write('type: $type, ')
          ..write('unsigned: $unsigned, ')
          ..write('content: $content, ')
          ..write('prevContent: $prevContent, ')
          ..write('stateKey: $stateKey, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => $mrjf($mrjc(
      clientId.hashCode,
      $mrjc(
          eventId.hashCode,
          $mrjc(
              roomId.hashCode,
              $mrjc(
                  sortOrder.hashCode,
                  $mrjc(
                      originServerTs.hashCode,
                      $mrjc(
                          sender.hashCode,
                          $mrjc(
                              type.hashCode,
                              $mrjc(
                                  unsigned.hashCode,
                                  $mrjc(
                                      content.hashCode,
                                      $mrjc(
                                          prevContent.hashCode,
                                          $mrjc(stateKey.hashCode,
                                              status.hashCode))))))))))));
  @override
  bool operator ==(dynamic other) =>
      identical(this, other) ||
      (other is DbEvent &&
          other.clientId == this.clientId &&
          other.eventId == this.eventId &&
          other.roomId == this.roomId &&
          other.sortOrder == this.sortOrder &&
          other.originServerTs == this.originServerTs &&
          other.sender == this.sender &&
          other.type == this.type &&
          other.unsigned == this.unsigned &&
          other.content == this.content &&
          other.prevContent == this.prevContent &&
          other.stateKey == this.stateKey &&
          other.status == this.status);
}

class EventsCompanion extends UpdateCompanion<DbEvent> {
  final Value<int> clientId;
  final Value<String> eventId;
  final Value<String> roomId;
  final Value<double> sortOrder;
  final Value<DateTime> originServerTs;
  final Value<String> sender;
  final Value<String> type;
  final Value<String> unsigned;
  final Value<String> content;
  final Value<String> prevContent;
  final Value<String> stateKey;
  final Value<int> status;
  const EventsCompanion({
    this.clientId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.roomId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.originServerTs = const Value.absent(),
    this.sender = const Value.absent(),
    this.type = const Value.absent(),
    this.unsigned = const Value.absent(),
    this.content = const Value.absent(),
    this.prevContent = const Value.absent(),
    this.stateKey = const Value.absent(),
    this.status = const Value.absent(),
  });
  EventsCompanion.insert({
    @required int clientId,
    @required String eventId,
    @required String roomId,
    @required double sortOrder,
    @required DateTime originServerTs,
    @required String sender,
    @required String type,
    this.unsigned = const Value.absent(),
    this.content = const Value.absent(),
    this.prevContent = const Value.absent(),
    this.stateKey = const Value.absent(),
    this.status = const Value.absent(),
  })  : clientId = Value(clientId),
        eventId = Value(eventId),
        roomId = Value(roomId),
        sortOrder = Value(sortOrder),
        originServerTs = Value(originServerTs),
        sender = Value(sender),
        type = Value(type);
  static Insertable<DbEvent> custom({
    Expression<int> clientId,
    Expression<String> eventId,
    Expression<String> roomId,
    Expression<double> sortOrder,
    Expression<DateTime> originServerTs,
    Expression<String> sender,
    Expression<String> type,
    Expression<String> unsigned,
    Expression<String> content,
    Expression<String> prevContent,
    Expression<String> stateKey,
    Expression<int> status,
  }) {
    return RawValuesInsertable({
      if (clientId != null) 'client_id': clientId,
      if (eventId != null) 'event_id': eventId,
      if (roomId != null) 'room_id': roomId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (originServerTs != null) 'origin_server_ts': originServerTs,
      if (sender != null) 'sender': sender,
      if (type != null) 'type': type,
      if (unsigned != null) 'unsigned': unsigned,
      if (content != null) 'content': content,
      if (prevContent != null) 'prev_content': prevContent,
      if (stateKey != null) 'state_key': stateKey,
      if (status != null) 'status': status,
    });
  }

  EventsCompanion copyWith(
      {Value<int> clientId,
      Value<String> eventId,
      Value<String> roomId,
      Value<double> sortOrder,
      Value<DateTime> originServerTs,
      Value<String> sender,
      Value<String> type,
      Value<String> unsigned,
      Value<String> content,
      Value<String> prevContent,
      Value<String> stateKey,
      Value<int> status}) {
    return EventsCompanion(
      clientId: clientId ?? this.clientId,
      eventId: eventId ?? this.eventId,
      roomId: roomId ?? this.roomId,
      sortOrder: sortOrder ?? this.sortOrder,
      originServerTs: originServerTs ?? this.originServerTs,
      sender: sender ?? this.sender,
      type: type ?? this.type,
      unsigned: unsigned ?? this.unsigned,
      content: content ?? this.content,
      prevContent: prevContent ?? this.prevContent,
      stateKey: stateKey ?? this.stateKey,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientId.present) {
      map['client_id'] = Variable<int>(clientId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (roomId.present) {
      map['room_id'] = Variable<String>(roomId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<double>(sortOrder.value);
    }
    if (originServerTs.present) {
      map['origin_server_ts'] = Variable<DateTime>(originServerTs.value);
    }
    if (sender.present) {
      map['sender'] = Variable<String>(sender.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (unsigned.present) {
      map['unsigned'] = Variable<String>(unsigned.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (prevContent.present) {
      map['prev_content'] = Variable<String>(prevContent.value);
    }
    if (stateKey.present) {
      map['state_key'] = Variable<String>(stateKey.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    return map;
  }
}

class Events extends Table with TableInfo<Events, DbEvent> {
  final GeneratedDatabase _db;
  final String _alias;
  Events(this._db, [this._alias]);
  final VerificationMeta _clientIdMeta = const VerificationMeta('clientId');
  GeneratedIntColumn _clientId;
  GeneratedIntColumn get clientId => _clientId ??= _constructClientId();
  GeneratedIntColumn _constructClientId() {
    return GeneratedIntColumn('client_id', $tableName, false,
        $customConstraints: 'NOT NULL REFERENCES clients(client_id)');
  }

  final VerificationMeta _eventIdMeta = const VerificationMeta('eventId');
  GeneratedTextColumn _eventId;
  GeneratedTextColumn get eventId => _eventId ??= _constructEventId();
  GeneratedTextColumn _constructEventId() {
    return GeneratedTextColumn('event_id', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _roomIdMeta = const VerificationMeta('roomId');
  GeneratedTextColumn _roomId;
  GeneratedTextColumn get roomId => _roomId ??= _constructRoomId();
  GeneratedTextColumn _constructRoomId() {
    return GeneratedTextColumn('room_id', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _sortOrderMeta = const VerificationMeta('sortOrder');
  GeneratedRealColumn _sortOrder;
  GeneratedRealColumn get sortOrder => _sortOrder ??= _constructSortOrder();
  GeneratedRealColumn _constructSortOrder() {
    return GeneratedRealColumn('sort_order', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _originServerTsMeta =
      const VerificationMeta('originServerTs');
  GeneratedDateTimeColumn _originServerTs;
  GeneratedDateTimeColumn get originServerTs =>
      _originServerTs ??= _constructOriginServerTs();
  GeneratedDateTimeColumn _constructOriginServerTs() {
    return GeneratedDateTimeColumn('origin_server_ts', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _senderMeta = const VerificationMeta('sender');
  GeneratedTextColumn _sender;
  GeneratedTextColumn get sender => _sender ??= _constructSender();
  GeneratedTextColumn _constructSender() {
    return GeneratedTextColumn('sender', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _typeMeta = const VerificationMeta('type');
  GeneratedTextColumn _type;
  GeneratedTextColumn get type => _type ??= _constructType();
  GeneratedTextColumn _constructType() {
    return GeneratedTextColumn('type', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _unsignedMeta = const VerificationMeta('unsigned');
  GeneratedTextColumn _unsigned;
  GeneratedTextColumn get unsigned => _unsigned ??= _constructUnsigned();
  GeneratedTextColumn _constructUnsigned() {
    return GeneratedTextColumn('unsigned', $tableName, true,
        $customConstraints: '');
  }

  final VerificationMeta _contentMeta = const VerificationMeta('content');
  GeneratedTextColumn _content;
  GeneratedTextColumn get content => _content ??= _constructContent();
  GeneratedTextColumn _constructContent() {
    return GeneratedTextColumn('content', $tableName, true,
        $customConstraints: '');
  }

  final VerificationMeta _prevContentMeta =
      const VerificationMeta('prevContent');
  GeneratedTextColumn _prevContent;
  GeneratedTextColumn get prevContent =>
      _prevContent ??= _constructPrevContent();
  GeneratedTextColumn _constructPrevContent() {
    return GeneratedTextColumn('prev_content', $tableName, true,
        $customConstraints: '');
  }

  final VerificationMeta _stateKeyMeta = const VerificationMeta('stateKey');
  GeneratedTextColumn _stateKey;
  GeneratedTextColumn get stateKey => _stateKey ??= _constructStateKey();
  GeneratedTextColumn _constructStateKey() {
    return GeneratedTextColumn('state_key', $tableName, true,
        $customConstraints: '');
  }

  final VerificationMeta _statusMeta = const VerificationMeta('status');
  GeneratedIntColumn _status;
  GeneratedIntColumn get status => _status ??= _constructStatus();
  GeneratedIntColumn _constructStatus() {
    return GeneratedIntColumn('status', $tableName, true,
        $customConstraints: '');
  }

  @override
  List<GeneratedColumn> get $columns => [
        clientId,
        eventId,
        roomId,
        sortOrder,
        originServerTs,
        sender,
        type,
        unsigned,
        content,
        prevContent,
        stateKey,
        status
      ];
  @override
  Events get asDslTable => this;
  @override
  String get $tableName => _alias ?? 'events';
  @override
  final String actualTableName = 'events';
  @override
  VerificationContext validateIntegrity(Insertable<DbEvent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id'], _clientIdMeta));
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(_eventIdMeta,
          eventId.isAcceptableOrUnknown(data['event_id'], _eventIdMeta));
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('room_id')) {
      context.handle(_roomIdMeta,
          roomId.isAcceptableOrUnknown(data['room_id'], _roomIdMeta));
    } else if (isInserting) {
      context.missing(_roomIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order'], _sortOrderMeta));
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('origin_server_ts')) {
      context.handle(
          _originServerTsMeta,
          originServerTs.isAcceptableOrUnknown(
              data['origin_server_ts'], _originServerTsMeta));
    } else if (isInserting) {
      context.missing(_originServerTsMeta);
    }
    if (data.containsKey('sender')) {
      context.handle(_senderMeta,
          sender.isAcceptableOrUnknown(data['sender'], _senderMeta));
    } else if (isInserting) {
      context.missing(_senderMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type'], _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('unsigned')) {
      context.handle(_unsignedMeta,
          unsigned.isAcceptableOrUnknown(data['unsigned'], _unsignedMeta));
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content'], _contentMeta));
    }
    if (data.containsKey('prev_content')) {
      context.handle(
          _prevContentMeta,
          prevContent.isAcceptableOrUnknown(
              data['prev_content'], _prevContentMeta));
    }
    if (data.containsKey('state_key')) {
      context.handle(_stateKeyMeta,
          stateKey.isAcceptableOrUnknown(data['state_key'], _stateKeyMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status'], _statusMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => <GeneratedColumn>{};
  @override
  DbEvent map(Map<String, dynamic> data, {String tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : null;
    return DbEvent.fromData(data, _db, prefix: effectivePrefix);
  }

  @override
  Events createAlias(String alias) {
    return Events(_db, alias);
  }

  @override
  List<String> get customConstraints =>
      const ['UNIQUE(client_id, event_id, room_id)'];
  @override
  bool get dontWriteConstraints => true;
}

class DbRoomState extends DataClass implements Insertable<DbRoomState> {
  final int clientId;
  final String eventId;
  final String roomId;
  final double sortOrder;
  final DateTime originServerTs;
  final String sender;
  final String type;
  final String unsigned;
  final String content;
  final String prevContent;
  final String stateKey;
  DbRoomState(
      {@required this.clientId,
      @required this.eventId,
      @required this.roomId,
      @required this.sortOrder,
      @required this.originServerTs,
      @required this.sender,
      @required this.type,
      this.unsigned,
      this.content,
      this.prevContent,
      @required this.stateKey});
  factory DbRoomState.fromData(Map<String, dynamic> data, GeneratedDatabase db,
      {String prefix}) {
    final effectivePrefix = prefix ?? '';
    final intType = db.typeSystem.forDartType<int>();
    final stringType = db.typeSystem.forDartType<String>();
    final doubleType = db.typeSystem.forDartType<double>();
    final dateTimeType = db.typeSystem.forDartType<DateTime>();
    return DbRoomState(
      clientId:
          intType.mapFromDatabaseResponse(data['${effectivePrefix}client_id']),
      eventId: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}event_id']),
      roomId:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}room_id']),
      sortOrder: doubleType
          .mapFromDatabaseResponse(data['${effectivePrefix}sort_order']),
      originServerTs: dateTimeType
          .mapFromDatabaseResponse(data['${effectivePrefix}origin_server_ts']),
      sender:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}sender']),
      type: stringType.mapFromDatabaseResponse(data['${effectivePrefix}type']),
      unsigned: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}unsigned']),
      content:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}content']),
      prevContent: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}prev_content']),
      stateKey: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}state_key']),
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || clientId != null) {
      map['client_id'] = Variable<int>(clientId);
    }
    if (!nullToAbsent || eventId != null) {
      map['event_id'] = Variable<String>(eventId);
    }
    if (!nullToAbsent || roomId != null) {
      map['room_id'] = Variable<String>(roomId);
    }
    if (!nullToAbsent || sortOrder != null) {
      map['sort_order'] = Variable<double>(sortOrder);
    }
    if (!nullToAbsent || originServerTs != null) {
      map['origin_server_ts'] = Variable<DateTime>(originServerTs);
    }
    if (!nullToAbsent || sender != null) {
      map['sender'] = Variable<String>(sender);
    }
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    if (!nullToAbsent || unsigned != null) {
      map['unsigned'] = Variable<String>(unsigned);
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || prevContent != null) {
      map['prev_content'] = Variable<String>(prevContent);
    }
    if (!nullToAbsent || stateKey != null) {
      map['state_key'] = Variable<String>(stateKey);
    }
    return map;
  }

  factory DbRoomState.fromJson(Map<String, dynamic> json,
      {ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return DbRoomState(
      clientId: serializer.fromJson<int>(json['client_id']),
      eventId: serializer.fromJson<String>(json['event_id']),
      roomId: serializer.fromJson<String>(json['room_id']),
      sortOrder: serializer.fromJson<double>(json['sort_order']),
      originServerTs: serializer.fromJson<DateTime>(json['origin_server_ts']),
      sender: serializer.fromJson<String>(json['sender']),
      type: serializer.fromJson<String>(json['type']),
      unsigned: serializer.fromJson<String>(json['unsigned']),
      content: serializer.fromJson<String>(json['content']),
      prevContent: serializer.fromJson<String>(json['prev_content']),
      stateKey: serializer.fromJson<String>(json['state_key']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'client_id': serializer.toJson<int>(clientId),
      'event_id': serializer.toJson<String>(eventId),
      'room_id': serializer.toJson<String>(roomId),
      'sort_order': serializer.toJson<double>(sortOrder),
      'origin_server_ts': serializer.toJson<DateTime>(originServerTs),
      'sender': serializer.toJson<String>(sender),
      'type': serializer.toJson<String>(type),
      'unsigned': serializer.toJson<String>(unsigned),
      'content': serializer.toJson<String>(content),
      'prev_content': serializer.toJson<String>(prevContent),
      'state_key': serializer.toJson<String>(stateKey),
    };
  }

  DbRoomState copyWith(
          {int clientId,
          String eventId,
          String roomId,
          double sortOrder,
          DateTime originServerTs,
          String sender,
          String type,
          String unsigned,
          String content,
          String prevContent,
          String stateKey}) =>
      DbRoomState(
        clientId: clientId ?? this.clientId,
        eventId: eventId ?? this.eventId,
        roomId: roomId ?? this.roomId,
        sortOrder: sortOrder ?? this.sortOrder,
        originServerTs: originServerTs ?? this.originServerTs,
        sender: sender ?? this.sender,
        type: type ?? this.type,
        unsigned: unsigned ?? this.unsigned,
        content: content ?? this.content,
        prevContent: prevContent ?? this.prevContent,
        stateKey: stateKey ?? this.stateKey,
      );
  @override
  String toString() {
    return (StringBuffer('DbRoomState(')
          ..write('clientId: $clientId, ')
          ..write('eventId: $eventId, ')
          ..write('roomId: $roomId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('originServerTs: $originServerTs, ')
          ..write('sender: $sender, ')
          ..write('type: $type, ')
          ..write('unsigned: $unsigned, ')
          ..write('content: $content, ')
          ..write('prevContent: $prevContent, ')
          ..write('stateKey: $stateKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => $mrjf($mrjc(
      clientId.hashCode,
      $mrjc(
          eventId.hashCode,
          $mrjc(
              roomId.hashCode,
              $mrjc(
                  sortOrder.hashCode,
                  $mrjc(
                      originServerTs.hashCode,
                      $mrjc(
                          sender.hashCode,
                          $mrjc(
                              type.hashCode,
                              $mrjc(
                                  unsigned.hashCode,
                                  $mrjc(
                                      content.hashCode,
                                      $mrjc(prevContent.hashCode,
                                          stateKey.hashCode)))))))))));
  @override
  bool operator ==(dynamic other) =>
      identical(this, other) ||
      (other is DbRoomState &&
          other.clientId == this.clientId &&
          other.eventId == this.eventId &&
          other.roomId == this.roomId &&
          other.sortOrder == this.sortOrder &&
          other.originServerTs == this.originServerTs &&
          other.sender == this.sender &&
          other.type == this.type &&
          other.unsigned == this.unsigned &&
          other.content == this.content &&
          other.prevContent == this.prevContent &&
          other.stateKey == this.stateKey);
}

class RoomStatesCompanion extends UpdateCompanion<DbRoomState> {
  final Value<int> clientId;
  final Value<String> eventId;
  final Value<String> roomId;
  final Value<double> sortOrder;
  final Value<DateTime> originServerTs;
  final Value<String> sender;
  final Value<String> type;
  final Value<String> unsigned;
  final Value<String> content;
  final Value<String> prevContent;
  final Value<String> stateKey;
  const RoomStatesCompanion({
    this.clientId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.roomId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.originServerTs = const Value.absent(),
    this.sender = const Value.absent(),
    this.type = const Value.absent(),
    this.unsigned = const Value.absent(),
    this.content = const Value.absent(),
    this.prevContent = const Value.absent(),
    this.stateKey = const Value.absent(),
  });
  RoomStatesCompanion.insert({
    @required int clientId,
    @required String eventId,
    @required String roomId,
    @required double sortOrder,
    @required DateTime originServerTs,
    @required String sender,
    @required String type,
    this.unsigned = const Value.absent(),
    this.content = const Value.absent(),
    this.prevContent = const Value.absent(),
    @required String stateKey,
  })  : clientId = Value(clientId),
        eventId = Value(eventId),
        roomId = Value(roomId),
        sortOrder = Value(sortOrder),
        originServerTs = Value(originServerTs),
        sender = Value(sender),
        type = Value(type),
        stateKey = Value(stateKey);
  static Insertable<DbRoomState> custom({
    Expression<int> clientId,
    Expression<String> eventId,
    Expression<String> roomId,
    Expression<double> sortOrder,
    Expression<DateTime> originServerTs,
    Expression<String> sender,
    Expression<String> type,
    Expression<String> unsigned,
    Expression<String> content,
    Expression<String> prevContent,
    Expression<String> stateKey,
  }) {
    return RawValuesInsertable({
      if (clientId != null) 'client_id': clientId,
      if (eventId != null) 'event_id': eventId,
      if (roomId != null) 'room_id': roomId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (originServerTs != null) 'origin_server_ts': originServerTs,
      if (sender != null) 'sender': sender,
      if (type != null) 'type': type,
      if (unsigned != null) 'unsigned': unsigned,
      if (content != null) 'content': content,
      if (prevContent != null) 'prev_content': prevContent,
      if (stateKey != null) 'state_key': stateKey,
    });
  }

  RoomStatesCompanion copyWith(
      {Value<int> clientId,
      Value<String> eventId,
      Value<String> roomId,
      Value<double> sortOrder,
      Value<DateTime> originServerTs,
      Value<String> sender,
      Value<String> type,
      Value<String> unsigned,
      Value<String> content,
      Value<String> prevContent,
      Value<String> stateKey}) {
    return RoomStatesCompanion(
      clientId: clientId ?? this.clientId,
      eventId: eventId ?? this.eventId,
      roomId: roomId ?? this.roomId,
      sortOrder: sortOrder ?? this.sortOrder,
      originServerTs: originServerTs ?? this.originServerTs,
      sender: sender ?? this.sender,
      type: type ?? this.type,
      unsigned: unsigned ?? this.unsigned,
      content: content ?? this.content,
      prevContent: prevContent ?? this.prevContent,
      stateKey: stateKey ?? this.stateKey,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientId.present) {
      map['client_id'] = Variable<int>(clientId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (roomId.present) {
      map['room_id'] = Variable<String>(roomId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<double>(sortOrder.value);
    }
    if (originServerTs.present) {
      map['origin_server_ts'] = Variable<DateTime>(originServerTs.value);
    }
    if (sender.present) {
      map['sender'] = Variable<String>(sender.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (unsigned.present) {
      map['unsigned'] = Variable<String>(unsigned.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (prevContent.present) {
      map['prev_content'] = Variable<String>(prevContent.value);
    }
    if (stateKey.present) {
      map['state_key'] = Variable<String>(stateKey.value);
    }
    return map;
  }
}

class RoomStates extends Table with TableInfo<RoomStates, DbRoomState> {
  final GeneratedDatabase _db;
  final String _alias;
  RoomStates(this._db, [this._alias]);
  final VerificationMeta _clientIdMeta = const VerificationMeta('clientId');
  GeneratedIntColumn _clientId;
  GeneratedIntColumn get clientId => _clientId ??= _constructClientId();
  GeneratedIntColumn _constructClientId() {
    return GeneratedIntColumn('client_id', $tableName, false,
        $customConstraints: 'NOT NULL REFERENCES clients(client_id)');
  }

  final VerificationMeta _eventIdMeta = const VerificationMeta('eventId');
  GeneratedTextColumn _eventId;
  GeneratedTextColumn get eventId => _eventId ??= _constructEventId();
  GeneratedTextColumn _constructEventId() {
    return GeneratedTextColumn('event_id', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _roomIdMeta = const VerificationMeta('roomId');
  GeneratedTextColumn _roomId;
  GeneratedTextColumn get roomId => _roomId ??= _constructRoomId();
  GeneratedTextColumn _constructRoomId() {
    return GeneratedTextColumn('room_id', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _sortOrderMeta = const VerificationMeta('sortOrder');
  GeneratedRealColumn _sortOrder;
  GeneratedRealColumn get sortOrder => _sortOrder ??= _constructSortOrder();
  GeneratedRealColumn _constructSortOrder() {
    return GeneratedRealColumn('sort_order', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _originServerTsMeta =
      const VerificationMeta('originServerTs');
  GeneratedDateTimeColumn _originServerTs;
  GeneratedDateTimeColumn get originServerTs =>
      _originServerTs ??= _constructOriginServerTs();
  GeneratedDateTimeColumn _constructOriginServerTs() {
    return GeneratedDateTimeColumn('origin_server_ts', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _senderMeta = const VerificationMeta('sender');
  GeneratedTextColumn _sender;
  GeneratedTextColumn get sender => _sender ??= _constructSender();
  GeneratedTextColumn _constructSender() {
    return GeneratedTextColumn('sender', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _typeMeta = const VerificationMeta('type');
  GeneratedTextColumn _type;
  GeneratedTextColumn get type => _type ??= _constructType();
  GeneratedTextColumn _constructType() {
    return GeneratedTextColumn('type', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _unsignedMeta = const VerificationMeta('unsigned');
  GeneratedTextColumn _unsigned;
  GeneratedTextColumn get unsigned => _unsigned ??= _constructUnsigned();
  GeneratedTextColumn _constructUnsigned() {
    return GeneratedTextColumn('unsigned', $tableName, true,
        $customConstraints: '');
  }

  final VerificationMeta _contentMeta = const VerificationMeta('content');
  GeneratedTextColumn _content;
  GeneratedTextColumn get content => _content ??= _constructContent();
  GeneratedTextColumn _constructContent() {
    return GeneratedTextColumn('content', $tableName, true,
        $customConstraints: '');
  }

  final VerificationMeta _prevContentMeta =
      const VerificationMeta('prevContent');
  GeneratedTextColumn _prevContent;
  GeneratedTextColumn get prevContent =>
      _prevContent ??= _constructPrevContent();
  GeneratedTextColumn _constructPrevContent() {
    return GeneratedTextColumn('prev_content', $tableName, true,
        $customConstraints: '');
  }

  final VerificationMeta _stateKeyMeta = const VerificationMeta('stateKey');
  GeneratedTextColumn _stateKey;
  GeneratedTextColumn get stateKey => _stateKey ??= _constructStateKey();
  GeneratedTextColumn _constructStateKey() {
    return GeneratedTextColumn('state_key', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  @override
  List<GeneratedColumn> get $columns => [
        clientId,
        eventId,
        roomId,
        sortOrder,
        originServerTs,
        sender,
        type,
        unsigned,
        content,
        prevContent,
        stateKey
      ];
  @override
  RoomStates get asDslTable => this;
  @override
  String get $tableName => _alias ?? 'room_states';
  @override
  final String actualTableName = 'room_states';
  @override
  VerificationContext validateIntegrity(Insertable<DbRoomState> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id'], _clientIdMeta));
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(_eventIdMeta,
          eventId.isAcceptableOrUnknown(data['event_id'], _eventIdMeta));
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('room_id')) {
      context.handle(_roomIdMeta,
          roomId.isAcceptableOrUnknown(data['room_id'], _roomIdMeta));
    } else if (isInserting) {
      context.missing(_roomIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order'], _sortOrderMeta));
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('origin_server_ts')) {
      context.handle(
          _originServerTsMeta,
          originServerTs.isAcceptableOrUnknown(
              data['origin_server_ts'], _originServerTsMeta));
    } else if (isInserting) {
      context.missing(_originServerTsMeta);
    }
    if (data.containsKey('sender')) {
      context.handle(_senderMeta,
          sender.isAcceptableOrUnknown(data['sender'], _senderMeta));
    } else if (isInserting) {
      context.missing(_senderMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type'], _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('unsigned')) {
      context.handle(_unsignedMeta,
          unsigned.isAcceptableOrUnknown(data['unsigned'], _unsignedMeta));
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content'], _contentMeta));
    }
    if (data.containsKey('prev_content')) {
      context.handle(
          _prevContentMeta,
          prevContent.isAcceptableOrUnknown(
              data['prev_content'], _prevContentMeta));
    }
    if (data.containsKey('state_key')) {
      context.handle(_stateKeyMeta,
          stateKey.isAcceptableOrUnknown(data['state_key'], _stateKeyMeta));
    } else if (isInserting) {
      context.missing(_stateKeyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => <GeneratedColumn>{};
  @override
  DbRoomState map(Map<String, dynamic> data, {String tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : null;
    return DbRoomState.fromData(data, _db, prefix: effectivePrefix);
  }

  @override
  RoomStates createAlias(String alias) {
    return RoomStates(_db, alias);
  }

  @override
  List<String> get customConstraints => const [
        'UNIQUE(client_id, event_id, room_id)',
        'UNIQUE(client_id, room_id, state_key, type)'
      ];
  @override
  bool get dontWriteConstraints => true;
}

class DbAccountData extends DataClass implements Insertable<DbAccountData> {
  final int clientId;
  final String type;
  final String content;
  DbAccountData({@required this.clientId, @required this.type, this.content});
  factory DbAccountData.fromData(
      Map<String, dynamic> data, GeneratedDatabase db,
      {String prefix}) {
    final effectivePrefix = prefix ?? '';
    final intType = db.typeSystem.forDartType<int>();
    final stringType = db.typeSystem.forDartType<String>();
    return DbAccountData(
      clientId:
          intType.mapFromDatabaseResponse(data['${effectivePrefix}client_id']),
      type: stringType.mapFromDatabaseResponse(data['${effectivePrefix}type']),
      content:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}content']),
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || clientId != null) {
      map['client_id'] = Variable<int>(clientId);
    }
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    return map;
  }

  factory DbAccountData.fromJson(Map<String, dynamic> json,
      {ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return DbAccountData(
      clientId: serializer.fromJson<int>(json['client_id']),
      type: serializer.fromJson<String>(json['type']),
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'client_id': serializer.toJson<int>(clientId),
      'type': serializer.toJson<String>(type),
      'content': serializer.toJson<String>(content),
    };
  }

  DbAccountData copyWith({int clientId, String type, String content}) =>
      DbAccountData(
        clientId: clientId ?? this.clientId,
        type: type ?? this.type,
        content: content ?? this.content,
      );
  @override
  String toString() {
    return (StringBuffer('DbAccountData(')
          ..write('clientId: $clientId, ')
          ..write('type: $type, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      $mrjf($mrjc(clientId.hashCode, $mrjc(type.hashCode, content.hashCode)));
  @override
  bool operator ==(dynamic other) =>
      identical(this, other) ||
      (other is DbAccountData &&
          other.clientId == this.clientId &&
          other.type == this.type &&
          other.content == this.content);
}

class AccountDataCompanion extends UpdateCompanion<DbAccountData> {
  final Value<int> clientId;
  final Value<String> type;
  final Value<String> content;
  const AccountDataCompanion({
    this.clientId = const Value.absent(),
    this.type = const Value.absent(),
    this.content = const Value.absent(),
  });
  AccountDataCompanion.insert({
    @required int clientId,
    @required String type,
    this.content = const Value.absent(),
  })  : clientId = Value(clientId),
        type = Value(type);
  static Insertable<DbAccountData> custom({
    Expression<int> clientId,
    Expression<String> type,
    Expression<String> content,
  }) {
    return RawValuesInsertable({
      if (clientId != null) 'client_id': clientId,
      if (type != null) 'type': type,
      if (content != null) 'content': content,
    });
  }

  AccountDataCompanion copyWith(
      {Value<int> clientId, Value<String> type, Value<String> content}) {
    return AccountDataCompanion(
      clientId: clientId ?? this.clientId,
      type: type ?? this.type,
      content: content ?? this.content,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientId.present) {
      map['client_id'] = Variable<int>(clientId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    return map;
  }
}

class AccountData extends Table with TableInfo<AccountData, DbAccountData> {
  final GeneratedDatabase _db;
  final String _alias;
  AccountData(this._db, [this._alias]);
  final VerificationMeta _clientIdMeta = const VerificationMeta('clientId');
  GeneratedIntColumn _clientId;
  GeneratedIntColumn get clientId => _clientId ??= _constructClientId();
  GeneratedIntColumn _constructClientId() {
    return GeneratedIntColumn('client_id', $tableName, false,
        $customConstraints: 'NOT NULL REFERENCES clients(client_id)');
  }

  final VerificationMeta _typeMeta = const VerificationMeta('type');
  GeneratedTextColumn _type;
  GeneratedTextColumn get type => _type ??= _constructType();
  GeneratedTextColumn _constructType() {
    return GeneratedTextColumn('type', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _contentMeta = const VerificationMeta('content');
  GeneratedTextColumn _content;
  GeneratedTextColumn get content => _content ??= _constructContent();
  GeneratedTextColumn _constructContent() {
    return GeneratedTextColumn('content', $tableName, true,
        $customConstraints: '');
  }

  @override
  List<GeneratedColumn> get $columns => [clientId, type, content];
  @override
  AccountData get asDslTable => this;
  @override
  String get $tableName => _alias ?? 'account_data';
  @override
  final String actualTableName = 'account_data';
  @override
  VerificationContext validateIntegrity(Insertable<DbAccountData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id'], _clientIdMeta));
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type'], _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content'], _contentMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => <GeneratedColumn>{};
  @override
  DbAccountData map(Map<String, dynamic> data, {String tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : null;
    return DbAccountData.fromData(data, _db, prefix: effectivePrefix);
  }

  @override
  AccountData createAlias(String alias) {
    return AccountData(_db, alias);
  }

  @override
  List<String> get customConstraints => const ['UNIQUE(client_id, type)'];
  @override
  bool get dontWriteConstraints => true;
}

class DbRoomAccountData extends DataClass
    implements Insertable<DbRoomAccountData> {
  final int clientId;
  final String type;
  final String roomId;
  final String content;
  DbRoomAccountData(
      {@required this.clientId,
      @required this.type,
      @required this.roomId,
      this.content});
  factory DbRoomAccountData.fromData(
      Map<String, dynamic> data, GeneratedDatabase db,
      {String prefix}) {
    final effectivePrefix = prefix ?? '';
    final intType = db.typeSystem.forDartType<int>();
    final stringType = db.typeSystem.forDartType<String>();
    return DbRoomAccountData(
      clientId:
          intType.mapFromDatabaseResponse(data['${effectivePrefix}client_id']),
      type: stringType.mapFromDatabaseResponse(data['${effectivePrefix}type']),
      roomId:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}room_id']),
      content:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}content']),
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || clientId != null) {
      map['client_id'] = Variable<int>(clientId);
    }
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    if (!nullToAbsent || roomId != null) {
      map['room_id'] = Variable<String>(roomId);
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    return map;
  }

  factory DbRoomAccountData.fromJson(Map<String, dynamic> json,
      {ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return DbRoomAccountData(
      clientId: serializer.fromJson<int>(json['client_id']),
      type: serializer.fromJson<String>(json['type']),
      roomId: serializer.fromJson<String>(json['room_id']),
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'client_id': serializer.toJson<int>(clientId),
      'type': serializer.toJson<String>(type),
      'room_id': serializer.toJson<String>(roomId),
      'content': serializer.toJson<String>(content),
    };
  }

  DbRoomAccountData copyWith(
          {int clientId, String type, String roomId, String content}) =>
      DbRoomAccountData(
        clientId: clientId ?? this.clientId,
        type: type ?? this.type,
        roomId: roomId ?? this.roomId,
        content: content ?? this.content,
      );
  @override
  String toString() {
    return (StringBuffer('DbRoomAccountData(')
          ..write('clientId: $clientId, ')
          ..write('type: $type, ')
          ..write('roomId: $roomId, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => $mrjf($mrjc(clientId.hashCode,
      $mrjc(type.hashCode, $mrjc(roomId.hashCode, content.hashCode))));
  @override
  bool operator ==(dynamic other) =>
      identical(this, other) ||
      (other is DbRoomAccountData &&
          other.clientId == this.clientId &&
          other.type == this.type &&
          other.roomId == this.roomId &&
          other.content == this.content);
}

class RoomAccountDataCompanion extends UpdateCompanion<DbRoomAccountData> {
  final Value<int> clientId;
  final Value<String> type;
  final Value<String> roomId;
  final Value<String> content;
  const RoomAccountDataCompanion({
    this.clientId = const Value.absent(),
    this.type = const Value.absent(),
    this.roomId = const Value.absent(),
    this.content = const Value.absent(),
  });
  RoomAccountDataCompanion.insert({
    @required int clientId,
    @required String type,
    @required String roomId,
    this.content = const Value.absent(),
  })  : clientId = Value(clientId),
        type = Value(type),
        roomId = Value(roomId);
  static Insertable<DbRoomAccountData> custom({
    Expression<int> clientId,
    Expression<String> type,
    Expression<String> roomId,
    Expression<String> content,
  }) {
    return RawValuesInsertable({
      if (clientId != null) 'client_id': clientId,
      if (type != null) 'type': type,
      if (roomId != null) 'room_id': roomId,
      if (content != null) 'content': content,
    });
  }

  RoomAccountDataCompanion copyWith(
      {Value<int> clientId,
      Value<String> type,
      Value<String> roomId,
      Value<String> content}) {
    return RoomAccountDataCompanion(
      clientId: clientId ?? this.clientId,
      type: type ?? this.type,
      roomId: roomId ?? this.roomId,
      content: content ?? this.content,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientId.present) {
      map['client_id'] = Variable<int>(clientId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (roomId.present) {
      map['room_id'] = Variable<String>(roomId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    return map;
  }
}

class RoomAccountData extends Table
    with TableInfo<RoomAccountData, DbRoomAccountData> {
  final GeneratedDatabase _db;
  final String _alias;
  RoomAccountData(this._db, [this._alias]);
  final VerificationMeta _clientIdMeta = const VerificationMeta('clientId');
  GeneratedIntColumn _clientId;
  GeneratedIntColumn get clientId => _clientId ??= _constructClientId();
  GeneratedIntColumn _constructClientId() {
    return GeneratedIntColumn('client_id', $tableName, false,
        $customConstraints: 'NOT NULL REFERENCES clients(client_id)');
  }

  final VerificationMeta _typeMeta = const VerificationMeta('type');
  GeneratedTextColumn _type;
  GeneratedTextColumn get type => _type ??= _constructType();
  GeneratedTextColumn _constructType() {
    return GeneratedTextColumn('type', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _roomIdMeta = const VerificationMeta('roomId');
  GeneratedTextColumn _roomId;
  GeneratedTextColumn get roomId => _roomId ??= _constructRoomId();
  GeneratedTextColumn _constructRoomId() {
    return GeneratedTextColumn('room_id', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _contentMeta = const VerificationMeta('content');
  GeneratedTextColumn _content;
  GeneratedTextColumn get content => _content ??= _constructContent();
  GeneratedTextColumn _constructContent() {
    return GeneratedTextColumn('content', $tableName, true,
        $customConstraints: '');
  }

  @override
  List<GeneratedColumn> get $columns => [clientId, type, roomId, content];
  @override
  RoomAccountData get asDslTable => this;
  @override
  String get $tableName => _alias ?? 'room_account_data';
  @override
  final String actualTableName = 'room_account_data';
  @override
  VerificationContext validateIntegrity(Insertable<DbRoomAccountData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id'], _clientIdMeta));
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type'], _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('room_id')) {
      context.handle(_roomIdMeta,
          roomId.isAcceptableOrUnknown(data['room_id'], _roomIdMeta));
    } else if (isInserting) {
      context.missing(_roomIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content'], _contentMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => <GeneratedColumn>{};
  @override
  DbRoomAccountData map(Map<String, dynamic> data, {String tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : null;
    return DbRoomAccountData.fromData(data, _db, prefix: effectivePrefix);
  }

  @override
  RoomAccountData createAlias(String alias) {
    return RoomAccountData(_db, alias);
  }

  @override
  List<String> get customConstraints =>
      const ['UNIQUE(client_id, type, room_id)'];
  @override
  bool get dontWriteConstraints => true;
}

class DbPresence extends DataClass implements Insertable<DbPresence> {
  final int clientId;
  final String type;
  final String sender;
  final String content;
  DbPresence(
      {@required this.clientId,
      @required this.type,
      @required this.sender,
      this.content});
  factory DbPresence.fromData(Map<String, dynamic> data, GeneratedDatabase db,
      {String prefix}) {
    final effectivePrefix = prefix ?? '';
    final intType = db.typeSystem.forDartType<int>();
    final stringType = db.typeSystem.forDartType<String>();
    return DbPresence(
      clientId:
          intType.mapFromDatabaseResponse(data['${effectivePrefix}client_id']),
      type: stringType.mapFromDatabaseResponse(data['${effectivePrefix}type']),
      sender:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}sender']),
      content:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}content']),
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || clientId != null) {
      map['client_id'] = Variable<int>(clientId);
    }
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    if (!nullToAbsent || sender != null) {
      map['sender'] = Variable<String>(sender);
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    return map;
  }

  factory DbPresence.fromJson(Map<String, dynamic> json,
      {ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return DbPresence(
      clientId: serializer.fromJson<int>(json['client_id']),
      type: serializer.fromJson<String>(json['type']),
      sender: serializer.fromJson<String>(json['sender']),
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'client_id': serializer.toJson<int>(clientId),
      'type': serializer.toJson<String>(type),
      'sender': serializer.toJson<String>(sender),
      'content': serializer.toJson<String>(content),
    };
  }

  DbPresence copyWith(
          {int clientId, String type, String sender, String content}) =>
      DbPresence(
        clientId: clientId ?? this.clientId,
        type: type ?? this.type,
        sender: sender ?? this.sender,
        content: content ?? this.content,
      );
  @override
  String toString() {
    return (StringBuffer('DbPresence(')
          ..write('clientId: $clientId, ')
          ..write('type: $type, ')
          ..write('sender: $sender, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => $mrjf($mrjc(clientId.hashCode,
      $mrjc(type.hashCode, $mrjc(sender.hashCode, content.hashCode))));
  @override
  bool operator ==(dynamic other) =>
      identical(this, other) ||
      (other is DbPresence &&
          other.clientId == this.clientId &&
          other.type == this.type &&
          other.sender == this.sender &&
          other.content == this.content);
}

class PresencesCompanion extends UpdateCompanion<DbPresence> {
  final Value<int> clientId;
  final Value<String> type;
  final Value<String> sender;
  final Value<String> content;
  const PresencesCompanion({
    this.clientId = const Value.absent(),
    this.type = const Value.absent(),
    this.sender = const Value.absent(),
    this.content = const Value.absent(),
  });
  PresencesCompanion.insert({
    @required int clientId,
    @required String type,
    @required String sender,
    this.content = const Value.absent(),
  })  : clientId = Value(clientId),
        type = Value(type),
        sender = Value(sender);
  static Insertable<DbPresence> custom({
    Expression<int> clientId,
    Expression<String> type,
    Expression<String> sender,
    Expression<String> content,
  }) {
    return RawValuesInsertable({
      if (clientId != null) 'client_id': clientId,
      if (type != null) 'type': type,
      if (sender != null) 'sender': sender,
      if (content != null) 'content': content,
    });
  }

  PresencesCompanion copyWith(
      {Value<int> clientId,
      Value<String> type,
      Value<String> sender,
      Value<String> content}) {
    return PresencesCompanion(
      clientId: clientId ?? this.clientId,
      type: type ?? this.type,
      sender: sender ?? this.sender,
      content: content ?? this.content,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientId.present) {
      map['client_id'] = Variable<int>(clientId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (sender.present) {
      map['sender'] = Variable<String>(sender.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    return map;
  }
}

class Presences extends Table with TableInfo<Presences, DbPresence> {
  final GeneratedDatabase _db;
  final String _alias;
  Presences(this._db, [this._alias]);
  final VerificationMeta _clientIdMeta = const VerificationMeta('clientId');
  GeneratedIntColumn _clientId;
  GeneratedIntColumn get clientId => _clientId ??= _constructClientId();
  GeneratedIntColumn _constructClientId() {
    return GeneratedIntColumn('client_id', $tableName, false,
        $customConstraints: 'NOT NULL REFERENCES clients(client_id)');
  }

  final VerificationMeta _typeMeta = const VerificationMeta('type');
  GeneratedTextColumn _type;
  GeneratedTextColumn get type => _type ??= _constructType();
  GeneratedTextColumn _constructType() {
    return GeneratedTextColumn('type', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _senderMeta = const VerificationMeta('sender');
  GeneratedTextColumn _sender;
  GeneratedTextColumn get sender => _sender ??= _constructSender();
  GeneratedTextColumn _constructSender() {
    return GeneratedTextColumn('sender', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _contentMeta = const VerificationMeta('content');
  GeneratedTextColumn _content;
  GeneratedTextColumn get content => _content ??= _constructContent();
  GeneratedTextColumn _constructContent() {
    return GeneratedTextColumn('content', $tableName, true,
        $customConstraints: '');
  }

  @override
  List<GeneratedColumn> get $columns => [clientId, type, sender, content];
  @override
  Presences get asDslTable => this;
  @override
  String get $tableName => _alias ?? 'presences';
  @override
  final String actualTableName = 'presences';
  @override
  VerificationContext validateIntegrity(Insertable<DbPresence> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id'], _clientIdMeta));
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type'], _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('sender')) {
      context.handle(_senderMeta,
          sender.isAcceptableOrUnknown(data['sender'], _senderMeta));
    } else if (isInserting) {
      context.missing(_senderMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content'], _contentMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => <GeneratedColumn>{};
  @override
  DbPresence map(Map<String, dynamic> data, {String tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : null;
    return DbPresence.fromData(data, _db, prefix: effectivePrefix);
  }

  @override
  Presences createAlias(String alias) {
    return Presences(_db, alias);
  }

  @override
  List<String> get customConstraints =>
      const ['UNIQUE(client_id, type, sender)'];
  @override
  bool get dontWriteConstraints => true;
}

class DbSSSSCache extends DataClass implements Insertable<DbSSSSCache> {
  final int clientId;
  final String type;
  final String keyId;
  final String ciphertext;
  final String content;
  DbSSSSCache(
      {@required this.clientId,
      @required this.type,
      @required this.keyId,
      @required this.ciphertext,
      @required this.content});
  factory DbSSSSCache.fromData(Map<String, dynamic> data, GeneratedDatabase db,
      {String prefix}) {
    final effectivePrefix = prefix ?? '';
    final intType = db.typeSystem.forDartType<int>();
    final stringType = db.typeSystem.forDartType<String>();
    return DbSSSSCache(
      clientId:
          intType.mapFromDatabaseResponse(data['${effectivePrefix}client_id']),
      type: stringType.mapFromDatabaseResponse(data['${effectivePrefix}type']),
      keyId:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}key_id']),
      ciphertext: stringType
          .mapFromDatabaseResponse(data['${effectivePrefix}ciphertext']),
      content:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}content']),
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || clientId != null) {
      map['client_id'] = Variable<int>(clientId);
    }
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    if (!nullToAbsent || keyId != null) {
      map['key_id'] = Variable<String>(keyId);
    }
    if (!nullToAbsent || ciphertext != null) {
      map['ciphertext'] = Variable<String>(ciphertext);
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    return map;
  }

  factory DbSSSSCache.fromJson(Map<String, dynamic> json,
      {ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return DbSSSSCache(
      clientId: serializer.fromJson<int>(json['client_id']),
      type: serializer.fromJson<String>(json['type']),
      keyId: serializer.fromJson<String>(json['key_id']),
      ciphertext: serializer.fromJson<String>(json['ciphertext']),
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'client_id': serializer.toJson<int>(clientId),
      'type': serializer.toJson<String>(type),
      'key_id': serializer.toJson<String>(keyId),
      'ciphertext': serializer.toJson<String>(ciphertext),
      'content': serializer.toJson<String>(content),
    };
  }

  DbSSSSCache copyWith(
          {int clientId,
          String type,
          String keyId,
          String ciphertext,
          String content}) =>
      DbSSSSCache(
        clientId: clientId ?? this.clientId,
        type: type ?? this.type,
        keyId: keyId ?? this.keyId,
        ciphertext: ciphertext ?? this.ciphertext,
        content: content ?? this.content,
      );
  @override
  String toString() {
    return (StringBuffer('DbSSSSCache(')
          ..write('clientId: $clientId, ')
          ..write('type: $type, ')
          ..write('keyId: $keyId, ')
          ..write('ciphertext: $ciphertext, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => $mrjf($mrjc(
      clientId.hashCode,
      $mrjc(
          type.hashCode,
          $mrjc(
              keyId.hashCode, $mrjc(ciphertext.hashCode, content.hashCode)))));
  @override
  bool operator ==(dynamic other) =>
      identical(this, other) ||
      (other is DbSSSSCache &&
          other.clientId == this.clientId &&
          other.type == this.type &&
          other.keyId == this.keyId &&
          other.ciphertext == this.ciphertext &&
          other.content == this.content);
}

class SsssCacheCompanion extends UpdateCompanion<DbSSSSCache> {
  final Value<int> clientId;
  final Value<String> type;
  final Value<String> keyId;
  final Value<String> ciphertext;
  final Value<String> content;
  const SsssCacheCompanion({
    this.clientId = const Value.absent(),
    this.type = const Value.absent(),
    this.keyId = const Value.absent(),
    this.ciphertext = const Value.absent(),
    this.content = const Value.absent(),
  });
  SsssCacheCompanion.insert({
    @required int clientId,
    @required String type,
    @required String keyId,
    @required String ciphertext,
    @required String content,
  })  : clientId = Value(clientId),
        type = Value(type),
        keyId = Value(keyId),
        ciphertext = Value(ciphertext),
        content = Value(content);
  static Insertable<DbSSSSCache> custom({
    Expression<int> clientId,
    Expression<String> type,
    Expression<String> keyId,
    Expression<String> ciphertext,
    Expression<String> content,
  }) {
    return RawValuesInsertable({
      if (clientId != null) 'client_id': clientId,
      if (type != null) 'type': type,
      if (keyId != null) 'key_id': keyId,
      if (ciphertext != null) 'ciphertext': ciphertext,
      if (content != null) 'content': content,
    });
  }

  SsssCacheCompanion copyWith(
      {Value<int> clientId,
      Value<String> type,
      Value<String> keyId,
      Value<String> ciphertext,
      Value<String> content}) {
    return SsssCacheCompanion(
      clientId: clientId ?? this.clientId,
      type: type ?? this.type,
      keyId: keyId ?? this.keyId,
      ciphertext: ciphertext ?? this.ciphertext,
      content: content ?? this.content,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientId.present) {
      map['client_id'] = Variable<int>(clientId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (keyId.present) {
      map['key_id'] = Variable<String>(keyId.value);
    }
    if (ciphertext.present) {
      map['ciphertext'] = Variable<String>(ciphertext.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    return map;
  }
}

class SsssCache extends Table with TableInfo<SsssCache, DbSSSSCache> {
  final GeneratedDatabase _db;
  final String _alias;
  SsssCache(this._db, [this._alias]);
  final VerificationMeta _clientIdMeta = const VerificationMeta('clientId');
  GeneratedIntColumn _clientId;
  GeneratedIntColumn get clientId => _clientId ??= _constructClientId();
  GeneratedIntColumn _constructClientId() {
    return GeneratedIntColumn('client_id', $tableName, false,
        $customConstraints: 'NOT NULL REFERENCES clients(client_id)');
  }

  final VerificationMeta _typeMeta = const VerificationMeta('type');
  GeneratedTextColumn _type;
  GeneratedTextColumn get type => _type ??= _constructType();
  GeneratedTextColumn _constructType() {
    return GeneratedTextColumn('type', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _keyIdMeta = const VerificationMeta('keyId');
  GeneratedTextColumn _keyId;
  GeneratedTextColumn get keyId => _keyId ??= _constructKeyId();
  GeneratedTextColumn _constructKeyId() {
    return GeneratedTextColumn('key_id', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _ciphertextMeta = const VerificationMeta('ciphertext');
  GeneratedTextColumn _ciphertext;
  GeneratedTextColumn get ciphertext => _ciphertext ??= _constructCiphertext();
  GeneratedTextColumn _constructCiphertext() {
    return GeneratedTextColumn('ciphertext', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  final VerificationMeta _contentMeta = const VerificationMeta('content');
  GeneratedTextColumn _content;
  GeneratedTextColumn get content => _content ??= _constructContent();
  GeneratedTextColumn _constructContent() {
    return GeneratedTextColumn('content', $tableName, false,
        $customConstraints: 'NOT NULL');
  }

  @override
  List<GeneratedColumn> get $columns =>
      [clientId, type, keyId, ciphertext, content];
  @override
  SsssCache get asDslTable => this;
  @override
  String get $tableName => _alias ?? 'ssss_cache';
  @override
  final String actualTableName = 'ssss_cache';
  @override
  VerificationContext validateIntegrity(Insertable<DbSSSSCache> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id'], _clientIdMeta));
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type'], _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('key_id')) {
      context.handle(
          _keyIdMeta, keyId.isAcceptableOrUnknown(data['key_id'], _keyIdMeta));
    } else if (isInserting) {
      context.missing(_keyIdMeta);
    }
    if (data.containsKey('ciphertext')) {
      context.handle(
          _ciphertextMeta,
          ciphertext.isAcceptableOrUnknown(
              data['ciphertext'], _ciphertextMeta));
    } else if (isInserting) {
      context.missing(_ciphertextMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content'], _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => <GeneratedColumn>{};
  @override
  DbSSSSCache map(Map<String, dynamic> data, {String tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : null;
    return DbSSSSCache.fromData(data, _db, prefix: effectivePrefix);
  }

  @override
  SsssCache createAlias(String alias) {
    return SsssCache(_db, alias);
  }

  @override
  List<String> get customConstraints => const ['UNIQUE(client_id, type)'];
  @override
  bool get dontWriteConstraints => true;
}

class DbFile extends DataClass implements Insertable<DbFile> {
  final String mxcUri;
  final Uint8List bytes;
  final DateTime savedAt;
  DbFile({@required this.mxcUri, this.bytes, this.savedAt});
  factory DbFile.fromData(Map<String, dynamic> data, GeneratedDatabase db,
      {String prefix}) {
    final effectivePrefix = prefix ?? '';
    final stringType = db.typeSystem.forDartType<String>();
    final uint8ListType = db.typeSystem.forDartType<Uint8List>();
    final dateTimeType = db.typeSystem.forDartType<DateTime>();
    return DbFile(
      mxcUri:
          stringType.mapFromDatabaseResponse(data['${effectivePrefix}mxc_uri']),
      bytes: uint8ListType
          .mapFromDatabaseResponse(data['${effectivePrefix}bytes']),
      savedAt: dateTimeType
          .mapFromDatabaseResponse(data['${effectivePrefix}saved_at']),
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || mxcUri != null) {
      map['mxc_uri'] = Variable<String>(mxcUri);
    }
    if (!nullToAbsent || bytes != null) {
      map['bytes'] = Variable<Uint8List>(bytes);
    }
    if (!nullToAbsent || savedAt != null) {
      map['saved_at'] = Variable<DateTime>(savedAt);
    }
    return map;
  }

  factory DbFile.fromJson(Map<String, dynamic> json,
      {ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return DbFile(
      mxcUri: serializer.fromJson<String>(json['mxc_uri']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
      savedAt: serializer.fromJson<DateTime>(json['saved_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer serializer}) {
    serializer ??= moorRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mxc_uri': serializer.toJson<String>(mxcUri),
      'bytes': serializer.toJson<Uint8List>(bytes),
      'saved_at': serializer.toJson<DateTime>(savedAt),
    };
  }

  DbFile copyWith({String mxcUri, Uint8List bytes, DateTime savedAt}) => DbFile(
        mxcUri: mxcUri ?? this.mxcUri,
        bytes: bytes ?? this.bytes,
        savedAt: savedAt ?? this.savedAt,
      );
  @override
  String toString() {
    return (StringBuffer('DbFile(')
          ..write('mxcUri: $mxcUri, ')
          ..write('bytes: $bytes, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      $mrjf($mrjc(mxcUri.hashCode, $mrjc(bytes.hashCode, savedAt.hashCode)));
  @override
  bool operator ==(dynamic other) =>
      identical(this, other) ||
      (other is DbFile &&
          other.mxcUri == this.mxcUri &&
          other.bytes == this.bytes &&
          other.savedAt == this.savedAt);
}

class FilesCompanion extends UpdateCompanion<DbFile> {
  final Value<String> mxcUri;
  final Value<Uint8List> bytes;
  final Value<DateTime> savedAt;
  const FilesCompanion({
    this.mxcUri = const Value.absent(),
    this.bytes = const Value.absent(),
    this.savedAt = const Value.absent(),
  });
  FilesCompanion.insert({
    @required String mxcUri,
    this.bytes = const Value.absent(),
    this.savedAt = const Value.absent(),
  }) : mxcUri = Value(mxcUri);
  static Insertable<DbFile> custom({
    Expression<String> mxcUri,
    Expression<Uint8List> bytes,
    Expression<DateTime> savedAt,
  }) {
    return RawValuesInsertable({
      if (mxcUri != null) 'mxc_uri': mxcUri,
      if (bytes != null) 'bytes': bytes,
      if (savedAt != null) 'saved_at': savedAt,
    });
  }

  FilesCompanion copyWith(
      {Value<String> mxcUri, Value<Uint8List> bytes, Value<DateTime> savedAt}) {
    return FilesCompanion(
      mxcUri: mxcUri ?? this.mxcUri,
      bytes: bytes ?? this.bytes,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mxcUri.present) {
      map['mxc_uri'] = Variable<String>(mxcUri.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    return map;
  }
}

class Files extends Table with TableInfo<Files, DbFile> {
  final GeneratedDatabase _db;
  final String _alias;
  Files(this._db, [this._alias]);
  final VerificationMeta _mxcUriMeta = const VerificationMeta('mxcUri');
  GeneratedTextColumn _mxcUri;
  GeneratedTextColumn get mxcUri => _mxcUri ??= _constructMxcUri();
  GeneratedTextColumn _constructMxcUri() {
    return GeneratedTextColumn('mxc_uri', $tableName, false,
        $customConstraints: 'NOT NULL PRIMARY KEY');
  }

  final VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  GeneratedBlobColumn _bytes;
  GeneratedBlobColumn get bytes => _bytes ??= _constructBytes();
  GeneratedBlobColumn _constructBytes() {
    return GeneratedBlobColumn('bytes', $tableName, true,
        $customConstraints: '');
  }

  final VerificationMeta _savedAtMeta = const VerificationMeta('savedAt');
  GeneratedDateTimeColumn _savedAt;
  GeneratedDateTimeColumn get savedAt => _savedAt ??= _constructSavedAt();
  GeneratedDateTimeColumn _constructSavedAt() {
    return GeneratedDateTimeColumn('saved_at', $tableName, true,
        $customConstraints: '');
  }

  @override
  List<GeneratedColumn> get $columns => [mxcUri, bytes, savedAt];
  @override
  Files get asDslTable => this;
  @override
  String get $tableName => _alias ?? 'files';
  @override
  final String actualTableName = 'files';
  @override
  VerificationContext validateIntegrity(Insertable<DbFile> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mxc_uri')) {
      context.handle(_mxcUriMeta,
          mxcUri.isAcceptableOrUnknown(data['mxc_uri'], _mxcUriMeta));
    } else if (isInserting) {
      context.missing(_mxcUriMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
          _bytesMeta, bytes.isAcceptableOrUnknown(data['bytes'], _bytesMeta));
    }
    if (data.containsKey('saved_at')) {
      context.handle(_savedAtMeta,
          savedAt.isAcceptableOrUnknown(data['saved_at'], _savedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mxcUri};
  @override
  DbFile map(Map<String, dynamic> data, {String tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : null;
    return DbFile.fromData(data, _db, prefix: effectivePrefix);
  }

  @override
  Files createAlias(String alias) {
    return Files(_db, alias);
  }

  @override
  List<String> get customConstraints => const ['UNIQUE(mxc_uri)'];
  @override
  bool get dontWriteConstraints => true;
}

abstract class _$Database extends GeneratedDatabase {
  _$Database(QueryExecutor e) : super(SqlTypeSystem.defaultInstance, e);
  _$Database.connect(DatabaseConnection c) : super.connect(c);
  Clients _clients;
  Clients get clients => _clients ??= Clients(this);
  UserDeviceKeys _userDeviceKeys;
  UserDeviceKeys get userDeviceKeys => _userDeviceKeys ??= UserDeviceKeys(this);
  Index _userDeviceKeysIndex;
  Index get userDeviceKeysIndex => _userDeviceKeysIndex ??= Index(
      'user_device_keys_index',
      'CREATE INDEX user_device_keys_index ON user_device_keys(client_id);');
  UserDeviceKeysKey _userDeviceKeysKey;
  UserDeviceKeysKey get userDeviceKeysKey =>
      _userDeviceKeysKey ??= UserDeviceKeysKey(this);
  Index _userDeviceKeysKeyIndex;
  Index get userDeviceKeysKeyIndex => _userDeviceKeysKeyIndex ??= Index(
      'user_device_keys_key_index',
      'CREATE INDEX user_device_keys_key_index ON user_device_keys_key(client_id);');
  UserCrossSigningKeys _userCrossSigningKeys;
  UserCrossSigningKeys get userCrossSigningKeys =>
      _userCrossSigningKeys ??= UserCrossSigningKeys(this);
  Index _userCrossSigningKeysIndex;
  Index get userCrossSigningKeysIndex => _userCrossSigningKeysIndex ??= Index(
      'user_cross_signing_keys_index',
      'CREATE INDEX user_cross_signing_keys_index ON user_cross_signing_keys(client_id);');
  OlmSessions _olmSessions;
  OlmSessions get olmSessions => _olmSessions ??= OlmSessions(this);
  Index _olmSessionsIndex;
  Index get olmSessionsIndex => _olmSessionsIndex ??= Index(
      'olm_sessions_index',
      'CREATE INDEX olm_sessions_index ON olm_sessions(client_id);');
  OutboundGroupSessions _outboundGroupSessions;
  OutboundGroupSessions get outboundGroupSessions =>
      _outboundGroupSessions ??= OutboundGroupSessions(this);
  Index _outboundGroupSessionsIndex;
  Index get outboundGroupSessionsIndex => _outboundGroupSessionsIndex ??= Index(
      'outbound_group_sessions_index',
      'CREATE INDEX outbound_group_sessions_index ON outbound_group_sessions(client_id);');
  InboundGroupSessions _inboundGroupSessions;
  InboundGroupSessions get inboundGroupSessions =>
      _inboundGroupSessions ??= InboundGroupSessions(this);
  Index _inboundGroupSessionsIndex;
  Index get inboundGroupSessionsIndex => _inboundGroupSessionsIndex ??= Index(
      'inbound_group_sessions_index',
      'CREATE INDEX inbound_group_sessions_index ON inbound_group_sessions(client_id);');
  Rooms _rooms;
  Rooms get rooms => _rooms ??= Rooms(this);
  Index _roomsIndex;
  Index get roomsIndex => _roomsIndex ??=
      Index('rooms_index', 'CREATE INDEX rooms_index ON rooms(client_id);');
  Events _events;
  Events get events => _events ??= Events(this);
  Index _eventsIndex;
  Index get eventsIndex => _eventsIndex ??= Index('events_index',
      'CREATE INDEX events_index ON events(client_id, room_id);');
  RoomStates _roomStates;
  RoomStates get roomStates => _roomStates ??= RoomStates(this);
  Index _roomStatesIndex;
  Index get roomStatesIndex => _roomStatesIndex ??= Index('room_states_index',
      'CREATE INDEX room_states_index ON room_states(client_id);');
  AccountData _accountData;
  AccountData get accountData => _accountData ??= AccountData(this);
  Index _accountDataIndex;
  Index get accountDataIndex => _accountDataIndex ??= Index(
      'account_data_index',
      'CREATE INDEX account_data_index ON account_data(client_id);');
  RoomAccountData _roomAccountData;
  RoomAccountData get roomAccountData =>
      _roomAccountData ??= RoomAccountData(this);
  Index _roomAccountDataIndex;
  Index get roomAccountDataIndex => _roomAccountDataIndex ??= Index(
      'room_account_data_index',
      'CREATE INDEX room_account_data_index ON room_account_data(client_id);');
  Presences _presences;
  Presences get presences => _presences ??= Presences(this);
  Index _presencesIndex;
  Index get presencesIndex => _presencesIndex ??= Index('presences_index',
      'CREATE INDEX presences_index ON presences(client_id);');
  SsssCache _ssssCache;
  SsssCache get ssssCache => _ssssCache ??= SsssCache(this);
  Files _files;
  Files get files => _files ??= Files(this);
  DbClient _rowToDbClient(QueryRow row) {
    return DbClient(
      clientId: row.readInt('client_id'),
      name: row.readString('name'),
      homeserverUrl: row.readString('homeserver_url'),
      token: row.readString('token'),
      userId: row.readString('user_id'),
      deviceId: row.readString('device_id'),
      deviceName: row.readString('device_name'),
      prevBatch: row.readString('prev_batch'),
      olmAccount: row.readString('olm_account'),
    );
  }

  Selectable<DbClient> dbGetClient(String name) {
    return customSelect('SELECT * FROM clients WHERE name = :name',
        variables: [Variable.withString(name)],
        readsFrom: {clients}).map(_rowToDbClient);
  }

  Future<int> updateClient(
      String homeserver_url,
      String token,
      String user_id,
      String device_id,
      String device_name,
      String prev_batch,
      String olm_account,
      int client_id) {
    return customUpdate(
      'UPDATE clients SET homeserver_url = :homeserver_url, token = :token, user_id = :user_id, device_id = :device_id, device_name = :device_name, prev_batch = :prev_batch, olm_account = :olm_account WHERE client_id = :client_id',
      variables: [
        Variable.withString(homeserver_url),
        Variable.withString(token),
        Variable.withString(user_id),
        Variable.withString(device_id),
        Variable.withString(device_name),
        Variable.withString(prev_batch),
        Variable.withString(olm_account),
        Variable.withInt(client_id)
      ],
      updates: {clients},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> updateClientKeys(String olm_account, int client_id) {
    return customUpdate(
      'UPDATE clients SET olm_account = :olm_account WHERE client_id = :client_id',
      variables: [
        Variable.withString(olm_account),
        Variable.withInt(client_id)
      ],
      updates: {clients},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> storePrevBatch(String prev_batch, int client_id) {
    return customUpdate(
      'UPDATE clients SET prev_batch = :prev_batch WHERE client_id = :client_id',
      variables: [Variable.withString(prev_batch), Variable.withInt(client_id)],
      updates: {clients},
      updateKind: UpdateKind.update,
    );
  }

  DbUserDeviceKey _rowToDbUserDeviceKey(QueryRow row) {
    return DbUserDeviceKey(
      clientId: row.readInt('client_id'),
      userId: row.readString('user_id'),
      outdated: row.readBool('outdated'),
    );
  }

  Selectable<DbUserDeviceKey> getAllUserDeviceKeys(int client_id) {
    return customSelect(
        'SELECT * FROM user_device_keys WHERE client_id = :client_id',
        variables: [Variable.withInt(client_id)],
        readsFrom: {userDeviceKeys}).map(_rowToDbUserDeviceKey);
  }

  DbUserDeviceKeysKey _rowToDbUserDeviceKeysKey(QueryRow row) {
    return DbUserDeviceKeysKey(
      clientId: row.readInt('client_id'),
      userId: row.readString('user_id'),
      deviceId: row.readString('device_id'),
      content: row.readString('content'),
      verified: row.readBool('verified'),
      blocked: row.readBool('blocked'),
    );
  }

  Selectable<DbUserDeviceKeysKey> getAllUserDeviceKeysKeys(int client_id) {
    return customSelect(
        'SELECT * FROM user_device_keys_key WHERE client_id = :client_id',
        variables: [Variable.withInt(client_id)],
        readsFrom: {userDeviceKeysKey}).map(_rowToDbUserDeviceKeysKey);
  }

  DbUserCrossSigningKey _rowToDbUserCrossSigningKey(QueryRow row) {
    return DbUserCrossSigningKey(
      clientId: row.readInt('client_id'),
      userId: row.readString('user_id'),
      publicKey: row.readString('public_key'),
      content: row.readString('content'),
      verified: row.readBool('verified'),
      blocked: row.readBool('blocked'),
    );
  }

  Selectable<DbUserCrossSigningKey> getAllUserCrossSigningKeys(int client_id) {
    return customSelect(
        'SELECT * FROM user_cross_signing_keys WHERE client_id = :client_id',
        variables: [Variable.withInt(client_id)],
        readsFrom: {userCrossSigningKeys}).map(_rowToDbUserCrossSigningKey);
  }

  DbOlmSessions _rowToDbOlmSessions(QueryRow row) {
    return DbOlmSessions(
      clientId: row.readInt('client_id'),
      identityKey: row.readString('identity_key'),
      sessionId: row.readString('session_id'),
      pickle: row.readString('pickle'),
      lastReceived: row.readDateTime('last_received'),
    );
  }

  Selectable<DbOlmSessions> getAllOlmSessions(int client_id) {
    return customSelect(
        'SELECT * FROM olm_sessions WHERE client_id = :client_id',
        variables: [Variable.withInt(client_id)],
        readsFrom: {olmSessions}).map(_rowToDbOlmSessions);
  }

  Selectable<DbOlmSessions> dbGetOlmSessions(
      int client_id, String identity_key) {
    return customSelect(
        'SELECT * FROM olm_sessions WHERE client_id = :client_id AND identity_key = :identity_key',
        variables: [
          Variable.withInt(client_id),
          Variable.withString(identity_key)
        ],
        readsFrom: {
          olmSessions
        }).map(_rowToDbOlmSessions);
  }

  Future<int> storeOlmSession(int client_id, String identitiy_key,
      String session_id, String pickle, DateTime last_received) {
    return customInsert(
      'INSERT OR REPLACE INTO olm_sessions (client_id, identity_key, session_id, pickle, last_received) VALUES (:client_id, :identitiy_key, :session_id, :pickle, :last_received)',
      variables: [
        Variable.withInt(client_id),
        Variable.withString(identitiy_key),
        Variable.withString(session_id),
        Variable.withString(pickle),
        Variable.withDateTime(last_received)
      ],
      updates: {olmSessions},
    );
  }

  DbOutboundGroupSession _rowToDbOutboundGroupSession(QueryRow row) {
    return DbOutboundGroupSession(
      clientId: row.readInt('client_id'),
      roomId: row.readString('room_id'),
      pickle: row.readString('pickle'),
      deviceIds: row.readString('device_ids'),
      creationTime: row.readDateTime('creation_time'),
      sentMessages: row.readInt('sent_messages'),
    );
  }

  Selectable<DbOutboundGroupSession> getAllOutboundGroupSessions(
      int client_id) {
    return customSelect(
        'SELECT * FROM outbound_group_sessions WHERE client_id = :client_id',
        variables: [Variable.withInt(client_id)],
        readsFrom: {outboundGroupSessions}).map(_rowToDbOutboundGroupSession);
  }

  Selectable<DbOutboundGroupSession> dbGetOutboundGroupSession(
      int client_id, String room_id) {
    return customSelect(
        'SELECT * FROM outbound_group_sessions WHERE client_id = :client_id AND room_id = :room_id',
        variables: [Variable.withInt(client_id), Variable.withString(room_id)],
        readsFrom: {outboundGroupSessions}).map(_rowToDbOutboundGroupSession);
  }

  Future<int> storeOutboundGroupSession(
      int client_id,
      String room_id,
      String pickle,
      String device_ids,
      DateTime creation_time,
      int sent_messages) {
    return customInsert(
      'INSERT OR REPLACE INTO outbound_group_sessions (client_id, room_id, pickle, device_ids, creation_time, sent_messages) VALUES (:client_id, :room_id, :pickle, :device_ids, :creation_time, :sent_messages)',
      variables: [
        Variable.withInt(client_id),
        Variable.withString(room_id),
        Variable.withString(pickle),
        Variable.withString(device_ids),
        Variable.withDateTime(creation_time),
        Variable.withInt(sent_messages)
      ],
      updates: {outboundGroupSessions},
    );
  }

  Future<int> removeOutboundGroupSession(int client_id, String room_id) {
    return customUpdate(
      'DELETE FROM outbound_group_sessions WHERE client_id = :client_id AND room_id = :room_id',
      variables: [Variable.withInt(client_id), Variable.withString(room_id)],
      updates: {outboundGroupSessions},
      updateKind: UpdateKind.delete,
    );
  }

  DbInboundGroupSession _rowToDbInboundGroupSession(QueryRow row) {
    return DbInboundGroupSession(
      clientId: row.readInt('client_id'),
      roomId: row.readString('room_id'),
      sessionId: row.readString('session_id'),
      pickle: row.readString('pickle'),
      content: row.readString('content'),
      indexes: row.readString('indexes'),
    );
  }

  Selectable<DbInboundGroupSession> dbGetInboundGroupSessionKey(
      int client_id, String room_id, String session_id) {
    return customSelect(
        'SELECT * FROM inbound_group_sessions WHERE client_id = :client_id AND room_id = :room_id AND session_id = :session_id',
        variables: [
          Variable.withInt(client_id),
          Variable.withString(room_id),
          Variable.withString(session_id)
        ],
        readsFrom: {
          inboundGroupSessions
        }).map(_rowToDbInboundGroupSession);
  }

  Selectable<DbInboundGroupSession> dbGetInboundGroupSessionKeys(
      int client_id, String room_id) {
    return customSelect(
        'SELECT * FROM inbound_group_sessions WHERE client_id = :client_id AND room_id = :room_id',
        variables: [Variable.withInt(client_id), Variable.withString(room_id)],
        readsFrom: {inboundGroupSessions}).map(_rowToDbInboundGroupSession);
  }

  Selectable<DbInboundGroupSession> getAllInboundGroupSessions(int client_id) {
    return customSelect(
        'SELECT * FROM inbound_group_sessions WHERE client_id = :client_id',
        variables: [Variable.withInt(client_id)],
        readsFrom: {inboundGroupSessions}).map(_rowToDbInboundGroupSession);
  }

  Future<int> storeInboundGroupSession(int client_id, String room_id,
      String session_id, String pickle, String content, String indexes) {
    return customInsert(
      'INSERT OR REPLACE INTO inbound_group_sessions (client_id, room_id, session_id, pickle, content, indexes) VALUES (:client_id, :room_id, :session_id, :pickle, :content, :indexes)',
      variables: [
        Variable.withInt(client_id),
        Variable.withString(room_id),
        Variable.withString(session_id),
        Variable.withString(pickle),
        Variable.withString(content),
        Variable.withString(indexes)
      ],
      updates: {inboundGroupSessions},
    );
  }

  Future<int> updateInboundGroupSessionIndexes(
      String indexes, int client_id, String room_id, String session_id) {
    return customUpdate(
      'UPDATE inbound_group_sessions SET indexes = :indexes WHERE client_id = :client_id AND room_id = :room_id AND session_id = :session_id',
      variables: [
        Variable.withString(indexes),
        Variable.withInt(client_id),
        Variable.withString(room_id),
        Variable.withString(session_id)
      ],
      updates: {inboundGroupSessions},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> storeUserDeviceKeysInfo(
      int client_id, String user_id, bool outdated) {
    return customInsert(
      'INSERT OR REPLACE INTO user_device_keys (client_id, user_id, outdated) VALUES (:client_id, :user_id, :outdated)',
      variables: [
        Variable.withInt(client_id),
        Variable.withString(user_id),
        Variable.withBool(outdated)
      ],
      updates: {userDeviceKeys},
    );
  }

  Future<int> setVerifiedUserDeviceKey(
      bool verified, int client_id, String user_id, String device_id) {
    return customUpdate(
      'UPDATE user_device_keys_key SET verified = :verified WHERE client_id = :client_id AND user_id = :user_id AND device_id = :device_id',
      variables: [
        Variable.withBool(verified),
        Variable.withInt(client_id),
        Variable.withString(user_id),
        Variable.withString(device_id)
      ],
      updates: {userDeviceKeysKey},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> setBlockedUserDeviceKey(
      bool blocked, int client_id, String user_id, String device_id) {
    return customUpdate(
      'UPDATE user_device_keys_key SET blocked = :blocked WHERE client_id = :client_id AND user_id = :user_id AND device_id = :device_id',
      variables: [
        Variable.withBool(blocked),
        Variable.withInt(client_id),
        Variable.withString(user_id),
        Variable.withString(device_id)
      ],
      updates: {userDeviceKeysKey},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> storeUserDeviceKey(int client_id, String user_id,
      String device_id, String content, bool verified, bool blocked) {
    return customInsert(
      'INSERT OR REPLACE INTO user_device_keys_key (client_id, user_id, device_id, content, verified, blocked) VALUES (:client_id, :user_id, :device_id, :content, :verified, :blocked)',
      variables: [
        Variable.withInt(client_id),
        Variable.withString(user_id),
        Variable.withString(device_id),
        Variable.withString(content),
        Variable.withBool(verified),
        Variable.withBool(blocked)
      ],
      updates: {userDeviceKeysKey},
    );
  }

  Future<int> removeUserDeviceKey(
      int client_id, String user_id, String device_id) {
    return customUpdate(
      'DELETE FROM user_device_keys_key WHERE client_id = :client_id AND user_id = :user_id AND device_id = :device_id',
      variables: [
        Variable.withInt(client_id),
        Variable.withString(user_id),
        Variable.withString(device_id)
      ],
      updates: {userDeviceKeysKey},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> setVerifiedUserCrossSigningKey(
      bool verified, int client_id, String user_id, String public_key) {
    return customUpdate(
      'UPDATE user_cross_signing_keys SET verified = :verified WHERE client_id = :client_id AND user_id = :user_id AND public_key = :public_key',
      variables: [
        Variable.withBool(verified),
        Variable.withInt(client_id),
        Variable.withString(user_id),
        Variable.withString(public_key)
      ],
      updates: {userCrossSigningKeys},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> setBlockedUserCrossSigningKey(
      bool blocked, int client_id, String user_id, String public_key) {
    return customUpdate(
      'UPDATE user_cross_signing_keys SET blocked = :blocked WHERE client_id = :client_id AND user_id = :user_id AND public_key = :public_key',
      variables: [
        Variable.withBool(blocked),
        Variable.withInt(client_id),
        Variable.withString(user_id),
        Variable.withString(public_key)
      ],
      updates: {userCrossSigningKeys},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> storeUserCrossSigningKey(int client_id, String user_id,
      String public_key, String content, bool verified, bool blocked) {
    return customInsert(
      'INSERT OR REPLACE INTO user_cross_signing_keys (client_id, user_id, public_key, content, verified, blocked) VALUES (:client_id, :user_id, :public_key, :content, :verified, :blocked)',
      variables: [
        Variable.withInt(client_id),
        Variable.withString(user_id),
        Variable.withString(public_key),
        Variable.withString(content),
        Variable.withBool(verified),
        Variable.withBool(blocked)
      ],
      updates: {userCrossSigningKeys},
    );
  }

  Future<int> removeUserCrossSigningKey(
      int client_id, String user_id, String public_key) {
    return customUpdate(
      'DELETE FROM user_cross_signing_keys WHERE client_id = :client_id AND user_id = :user_id AND public_key = :public_key',
      variables: [
        Variable.withInt(client_id),
        Variable.withString(user_id),
        Variable.withString(public_key)
      ],
      updates: {userCrossSigningKeys},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> storeSSSSCache(int client_id, String type, String key_id,
      String ciphertext, String content) {
    return customInsert(
      'INSERT OR REPLACE INTO ssss_cache (client_id, type, key_id, ciphertext, content) VALUES (:client_id, :type, :key_id, :ciphertext, :content)',
      variables: [
        Variable.withInt(client_id),
        Variable.withString(type),
        Variable.withString(key_id),
        Variable.withString(ciphertext),
        Variable.withString(content)
      ],
      updates: {ssssCache},
    );
  }

  DbSSSSCache _rowToDbSSSSCache(QueryRow row) {
    return DbSSSSCache(
      clientId: row.readInt('client_id'),
      type: row.readString('type'),
      keyId: row.readString('key_id'),
      ciphertext: row.readString('ciphertext'),
      content: row.readString('content'),
    );
  }

  Selectable<DbSSSSCache> dbGetSSSSCache(int client_id, String type) {
    return customSelect(
        'SELECT * FROM ssss_cache WHERE client_id = :client_id AND type = :type',
        variables: [Variable.withInt(client_id), Variable.withString(type)],
        readsFrom: {ssssCache}).map(_rowToDbSSSSCache);
  }

  Future<int> clearSSSSCache(int client_id) {
    return customUpdate(
      'DELETE FROM ssss_cache WHERE client_id = :client_id',
      variables: [Variable.withInt(client_id)],
      updates: {ssssCache},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> insertClient(
      String name,
      String homeserver_url,
      String token,
      String user_id,
      String device_id,
      String device_name,
      String prev_batch,
      String olm_account) {
    return customInsert(
      'INSERT INTO clients (name, homeserver_url, token, user_id, device_id, device_name, prev_batch, olm_account) VALUES (:name, :homeserver_url, :token, :user_id, :device_id, :device_name, :prev_batch, :olm_account)',
      variables: [
        Variable.withString(name),
        Variable.withString(homeserver_url),
        Variable.withString(token),
        Variable.withString(user_id),
        Variable.withString(device_id),
        Variable.withString(device_name),
        Variable.withString(prev_batch),
        Variable.withString(olm_account)
      ],
      updates: {clients},
    );
  }

  Future<int> ensureRoomExists(
      int client_id, String room_id, String membership) {
    return customInsert(
      'INSERT OR IGNORE INTO rooms (client_id, room_id, membership) VALUES (:client_id, :room_id, :membership)',
      variables: [
        Variable.withInt(client_id),
        Variable.withString(room_id),
        Variable.withString(membership)
      ],
      updates: {rooms},
    );
  }

  Future<int> setRoomPrevBatch(
      String prev_batch, int client_id, String room_id) {
    return customUpdate(
      'UPDATE rooms SET prev_batch = :prev_batch WHERE client_id = :client_id AND room_id = :room_id',
      variables: [
        Variable.withString(prev_batch),
        Variable.withInt(client_id),
        Variable.withString(room_id)
      ],
      updates: {rooms},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> updateRoomSortOrder(double oldest_sort_order,
      double newest_sort_order, int client_id, String room_id) {
    return customUpdate(
      'UPDATE rooms SET oldest_sort_order = :oldest_sort_order, newest_sort_order = :newest_sort_order WHERE client_id = :client_id AND room_id = :room_id',
      variables: [
        Variable.withReal(oldest_sort_order),
        Variable.withReal(newest_sort_order),
        Variable.withInt(client_id),
        Variable.withString(room_id)
      ],
      updates: {rooms},
      updateKind: UpdateKind.update,
    );
  }

  DbAccountData _rowToDbAccountData(QueryRow row) {
    return DbAccountData(
      clientId: row.readInt('client_id'),
      type: row.readString('type'),
      content: row.readString('content'),
    );
  }

  Selectable<DbAccountData> getAllAccountData(int client_id) {
    return customSelect(
        'SELECT * FROM account_data WHERE client_id = :client_id',
        variables: [Variable.withInt(client_id)],
        readsFrom: {accountData}).map(_rowToDbAccountData);
  }

  Future<int> storeAccountData(int client_id, String type, String content) {
    return customInsert(
      'INSERT OR REPLACE INTO account_data (client_id, type, content) VALUES (:client_id, :type, :content)',
      variables: [
        Variable.withInt(client_id),
        Variable.withString(type),
        Variable.withString(content)
      ],
      updates: {accountData},
    );
  }

  Future<int> updateEvent(String unsigned, String content, String prev_content,
      int client_id, String event_id, String room_id) {
    return customUpdate(
      'UPDATE events SET unsigned = :unsigned, content = :content, prev_content = :prev_content WHERE client_id = :client_id AND event_id = :event_id AND room_id = :room_id',
      variables: [
        Variable.withString(unsigned),
        Variable.withString(content),
        Variable.withString(prev_content),
        Variable.withInt(client_id),
        Variable.withString(event_id),
        Variable.withString(room_id)
      ],
      updates: {events},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> updateEventStatus(int status, String new_event_id, int client_id,
      String old_event_id, String room_id) {
    return customUpdate(
      'UPDATE events SET status = :status, event_id = :new_event_id WHERE client_id = :client_id AND event_id = :old_event_id AND room_id = :room_id',
      variables: [
        Variable.withInt(status),
        Variable.withString(new_event_id),
        Variable.withInt(client_id),
        Variable.withString(old_event_id),
        Variable.withString(room_id)
      ],
      updates: {events},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> updateEventStatusOnly(
      int status, int client_id, String event_id, String room_id) {
    return customUpdate(
      'UPDATE events SET status = :status WHERE client_id = :client_id AND event_id = :event_id AND room_id = :room_id',
      variables: [
        Variable.withInt(status),
        Variable.withInt(client_id),
        Variable.withString(event_id),
        Variable.withString(room_id)
      ],
      updates: {events},
      updateKind: UpdateKind.update,
    );
  }

  DbRoomState _rowToDbRoomState(QueryRow row) {
    return DbRoomState(
      clientId: row.readInt('client_id'),
      eventId: row.readString('event_id'),
      roomId: row.readString('room_id'),
      sortOrder: row.readDouble('sort_order'),
      originServerTs: row.readDateTime('origin_server_ts'),
      sender: row.readString('sender'),
      type: row.readString('type'),
      unsigned: row.readString('unsigned'),
      content: row.readString('content'),
      prevContent: row.readString('prev_content'),
      stateKey: row.readString('state_key'),
    );
  }

  Selectable<DbRoomState> getImportantRoomStates(
      int client_id, List<String> events) {
    var $arrayStartIndex = 2;
    final expandedevents = $expandVar($arrayStartIndex, events.length);
    $arrayStartIndex += events.length;
    return customSelect(
        'SELECT * FROM room_states WHERE client_id = :client_id AND type IN ($expandedevents)',
        variables: [
          Variable.withInt(client_id),
          for (var $ in events) Variable.withString($)
        ],
        readsFrom: {
          roomStates
        }).map(_rowToDbRoomState);
  }

  Selectable<DbRoomState> getAllRoomStates(int client_id) {
    return customSelect(
        'SELECT * FROM room_states WHERE client_id = :client_id',
        variables: [Variable.withInt(client_id)],
        readsFrom: {roomStates}).map(_rowToDbRoomState);
  }

  Selectable<DbRoomState> getUnimportantRoomStatesForRoom(
      int client_id, String room_id, List<String> events) {
    var $arrayStartIndex = 3;
    final expandedevents = $expandVar($arrayStartIndex, events.length);
    $arrayStartIndex += events.length;
    return customSelect(
        'SELECT * FROM room_states WHERE client_id = :client_id AND room_id = :room_id AND type NOT IN ($expandedevents)',
        variables: [
          Variable.withInt(client_id),
          Variable.withString(room_id),
          for (var $ in events) Variable.withString($)
        ],
        readsFrom: {
          roomStates
        }).map(_rowToDbRoomState);
  }

  Future<int> storeEvent(
      int client_id,
      String event_id,
      String room_id,
      double sort_order,
      DateTime origin_server_ts,
      String sender,
      String type,
      String unsigned,
      String content,
      String prev_content,
      String state_key,
      int status) {
    return customInsert(
      'INSERT OR REPLACE INTO events (client_id, event_id, room_id, sort_order, origin_server_ts, sender, type, unsigned, content, prev_content, state_key, status) VALUES (:client_id, :event_id, :room_id, :sort_order, :origin_server_ts, :sender, :type, :unsigned, :content, :prev_content, :state_key, :status)',
      variables: [
        Variable.withInt(client_id),
        Variable.withString(event_id),
        Variable.withString(room_id),
        Variable.withReal(sort_order),
        Variable.withDateTime(origin_server_ts),
        Variable.withString(sender),
        Variable.withString(type),
        Variable.withString(unsigned),
        Variable.withString(content),
        Variable.withString(prev_content),
        Variable.withString(state_key),
        Variable.withInt(status)
      ],
      updates: {events},
    );
  }

  Future<int> storeRoomState(
      int client_id,
      String event_id,
      String room_id,
      double sort_order,
      DateTime origin_server_ts,
      String sender,
      String type,
      String unsigned,
      String content,
      String prev_content,
      String state_key) {
    return customInsert(
      'INSERT OR REPLACE INTO room_states (client_id, event_id, room_id, sort_order, origin_server_ts, sender, type, unsigned, content, prev_content, state_key) VALUES (:client_id, :event_id, :room_id, :sort_order, :origin_server_ts, :sender, :type, :unsigned, :content, :prev_content, :state_key)',
      variables: [
        Variable.withInt(client_id),
        Variable.withString(event_id),
        Variable.withString(room_id),
        Variable.withReal(sort_order),
        Variable.withDateTime(origin_server_ts),
        Variable.withString(sender),
        Variable.withString(type),
        Variable.withString(unsigned),
        Variable.withString(content),
        Variable.withString(prev_content),
        Variable.withString(state_key)
      ],
      updates: {roomStates},
    );
  }

  DbRoomAccountData _rowToDbRoomAccountData(QueryRow row) {
    return DbRoomAccountData(
      clientId: row.readInt('client_id'),
      type: row.readString('type'),
      roomId: row.readString('room_id'),
      content: row.readString('content'),
    );
  }

  Selectable<DbRoomAccountData> getAllRoomAccountData(int client_id) {
    return customSelect(
        'SELECT * FROM room_account_data WHERE client_id = :client_id',
        variables: [Variable.withInt(client_id)],
        readsFrom: {roomAccountData}).map(_rowToDbRoomAccountData);
  }

  Future<int> storeRoomAccountData(
      int client_id, String type, String room_id, String content) {
    return customInsert(
      'INSERT OR REPLACE INTO room_account_data (client_id, type, room_id, content) VALUES (:client_id, :type, :room_id, :content)',
      variables: [
        Variable.withInt(client_id),
        Variable.withString(type),
        Variable.withString(room_id),
        Variable.withString(content)
      ],
      updates: {roomAccountData},
    );
  }

  Selectable<DbRoomState> dbGetUser(
      int client_id, String state_key, String room_id) {
    return customSelect(
        'SELECT * FROM room_states WHERE client_id = :client_id AND type = \'m.room.member\' AND state_key = :state_key AND room_id = :room_id',
        variables: [
          Variable.withInt(client_id),
          Variable.withString(state_key),
          Variable.withString(room_id)
        ],
        readsFrom: {
          roomStates
        }).map(_rowToDbRoomState);
  }

  Selectable<DbRoomState> dbGetUsers(int client_id, String room_id) {
    return customSelect(
        'SELECT * FROM room_states WHERE client_id = :client_id AND type = \'m.room.member\' AND room_id = :room_id',
        variables: [Variable.withInt(client_id), Variable.withString(room_id)],
        readsFrom: {roomStates}).map(_rowToDbRoomState);
  }

  DbEvent _rowToDbEvent(QueryRow row) {
    return DbEvent(
      clientId: row.readInt('client_id'),
      eventId: row.readString('event_id'),
      roomId: row.readString('room_id'),
      sortOrder: row.readDouble('sort_order'),
      originServerTs: row.readDateTime('origin_server_ts'),
      sender: row.readString('sender'),
      type: row.readString('type'),
      unsigned: row.readString('unsigned'),
      content: row.readString('content'),
      prevContent: row.readString('prev_content'),
      stateKey: row.readString('state_key'),
      status: row.readInt('status'),
    );
  }

  Selectable<DbEvent> dbGetEventList(int client_id, String room_id) {
    return customSelect(
        'SELECT * FROM events WHERE client_id = :client_id AND room_id = :room_id GROUP BY event_id ORDER BY sort_order DESC',
        variables: [Variable.withInt(client_id), Variable.withString(room_id)],
        readsFrom: {events}).map(_rowToDbEvent);
  }

  Selectable<DbRoomState> getStates(int client_id, String room_id) {
    return customSelect(
        'SELECT * FROM room_states WHERE client_id = :client_id AND room_id = :room_id',
        variables: [Variable.withInt(client_id), Variable.withString(room_id)],
        readsFrom: {roomStates}).map(_rowToDbRoomState);
  }

  Future<int> resetNotificationCount(int client_id, String room_id) {
    return customUpdate(
      'UPDATE rooms SET notification_count = 0, highlight_count = 0 WHERE client_id = :client_id AND room_id = :room_id',
      variables: [Variable.withInt(client_id), Variable.withString(room_id)],
      updates: {rooms},
      updateKind: UpdateKind.update,
    );
  }

  DbRoom _rowToDbRoom(QueryRow row) {
    return DbRoom(
      clientId: row.readInt('client_id'),
      roomId: row.readString('room_id'),
      membership: row.readString('membership'),
      highlightCount: row.readInt('highlight_count'),
      notificationCount: row.readInt('notification_count'),
      prevBatch: row.readString('prev_batch'),
      joinedMemberCount: row.readInt('joined_member_count'),
      invitedMemberCount: row.readInt('invited_member_count'),
      newestSortOrder: row.readDouble('newest_sort_order'),
      oldestSortOrder: row.readDouble('oldest_sort_order'),
      heroes: row.readString('heroes'),
    );
  }

  Selectable<DbRoom> getRoom(int client_id, String room_id) {
    return customSelect(
        'SELECT * FROM rooms WHERE client_id = :client_id AND room_id = :room_id',
        variables: [Variable.withInt(client_id), Variable.withString(room_id)],
        readsFrom: {rooms}).map(_rowToDbRoom);
  }

  Selectable<DbEvent> getEvent(int client_id, String event_id, String room_id) {
    return customSelect(
        'SELECT * FROM events WHERE client_id = :client_id AND event_id = :event_id AND room_id = :room_id',
        variables: [
          Variable.withInt(client_id),
          Variable.withString(event_id),
          Variable.withString(room_id)
        ],
        readsFrom: {
          events
        }).map(_rowToDbEvent);
  }

  Future<int> removeEvent(int client_id, String event_id, String room_id) {
    return customUpdate(
      'DELETE FROM events WHERE client_id = :client_id AND event_id = :event_id AND room_id = :room_id',
      variables: [
        Variable.withInt(client_id),
        Variable.withString(event_id),
        Variable.withString(room_id)
      ],
      updates: {events},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> removeRoom(int client_id, String room_id) {
    return customUpdate(
      'DELETE FROM rooms WHERE client_id = :client_id AND room_id = :room_id',
      variables: [Variable.withInt(client_id), Variable.withString(room_id)],
      updates: {rooms},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> removeRoomEvents(int client_id, String room_id) {
    return customUpdate(
      'DELETE FROM events WHERE client_id = :client_id AND room_id = :room_id',
      variables: [Variable.withInt(client_id), Variable.withString(room_id)],
      updates: {events},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> storeFile(String mxc_uri, Uint8List bytes, DateTime time) {
    return customInsert(
      'INSERT OR REPLACE INTO files (mxc_uri, bytes, saved_at) VALUES (:mxc_uri, :bytes, :time)',
      variables: [
        Variable.withString(mxc_uri),
        Variable.withBlob(bytes),
        Variable.withDateTime(time)
      ],
      updates: {files},
    );
  }

  DbFile _rowToDbFile(QueryRow row) {
    return DbFile(
      mxcUri: row.readString('mxc_uri'),
      bytes: row.readBlob('bytes'),
      savedAt: row.readDateTime('saved_at'),
    );
  }

  Selectable<DbFile> dbGetFile(String mxc_uri) {
    return customSelect('SELECT * FROM files WHERE mxc_uri = :mxc_uri',
        variables: [Variable.withString(mxc_uri)],
        readsFrom: {files}).map(_rowToDbFile);
  }

  @override
  Iterable<TableInfo> get allTables => allSchemaEntities.whereType<TableInfo>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        clients,
        userDeviceKeys,
        userDeviceKeysIndex,
        userDeviceKeysKey,
        userDeviceKeysKeyIndex,
        userCrossSigningKeys,
        userCrossSigningKeysIndex,
        olmSessions,
        olmSessionsIndex,
        outboundGroupSessions,
        outboundGroupSessionsIndex,
        inboundGroupSessions,
        inboundGroupSessionsIndex,
        rooms,
        roomsIndex,
        events,
        eventsIndex,
        roomStates,
        roomStatesIndex,
        accountData,
        accountDataIndex,
        roomAccountData,
        roomAccountDataIndex,
        presences,
        presencesIndex,
        ssssCache,
        files
      ];
}
