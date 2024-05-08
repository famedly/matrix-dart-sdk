// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// EnhancedEnumGenerator
// **************************************************************************

extension DirectionFromStringExtension on Iterable<Direction> {
  Direction? fromString(String val) {
    final override = {
      'b': Direction.b,
      'f': Direction.f,
    }[val];
// ignore: unnecessary_this
    return this.contains(override) ? override : null;
  }
}

extension DirectionEnhancedEnum on Direction {
  @override
// ignore: override_on_non_overriding_member
  String get name => {
        Direction.b: 'b',
        Direction.f: 'f',
      }[this]!;
  bool get isB => this == Direction.b;
  bool get isF => this == Direction.f;
  T when<T>({
    required T Function() b,
    required T Function() f,
  }) =>
      {
        Direction.b: b,
        Direction.f: f,
      }[this]!();
  T maybeWhen<T>({
    T? Function()? b,
    T? Function()? f,
    required T Function() orElse,
  }) =>
      {
        Direction.b: b,
        Direction.f: f,
      }[this]
          ?.call() ??
      orElse();
}

extension IncludeFromStringExtension on Iterable<Include> {
  Include? fromString(String val) {
    final override = {
      'all': Include.all,
      'participated': Include.participated,
    }[val];
// ignore: unnecessary_this
    return this.contains(override) ? override : null;
  }
}

extension IncludeEnhancedEnum on Include {
  @override
// ignore: override_on_non_overriding_member
  String get name => {
        Include.all: 'all',
        Include.participated: 'participated',
      }[this]!;
  bool get isAll => this == Include.all;
  bool get isParticipated => this == Include.participated;
  T when<T>({
    required T Function() all,
    required T Function() participated,
  }) =>
      {
        Include.all: all,
        Include.participated: participated,
      }[this]!();
  T maybeWhen<T>({
    T? Function()? all,
    T? Function()? participated,
    required T Function() orElse,
  }) =>
      {
        Include.all: all,
        Include.participated: participated,
      }[this]
          ?.call() ??
      orElse();
}

extension ThirdPartyIdentifierMediumFromStringExtension
    on Iterable<ThirdPartyIdentifierMedium> {
  ThirdPartyIdentifierMedium? fromString(String val) {
    final override = {
      'email': ThirdPartyIdentifierMedium.email,
      'msisdn': ThirdPartyIdentifierMedium.msisdn,
    }[val];
// ignore: unnecessary_this
    return this.contains(override) ? override : null;
  }
}

extension ThirdPartyIdentifierMediumEnhancedEnum on ThirdPartyIdentifierMedium {
  @override
// ignore: override_on_non_overriding_member
  String get name => {
        ThirdPartyIdentifierMedium.email: 'email',
        ThirdPartyIdentifierMedium.msisdn: 'msisdn',
      }[this]!;
  bool get isEmail => this == ThirdPartyIdentifierMedium.email;
  bool get isMsisdn => this == ThirdPartyIdentifierMedium.msisdn;
  T when<T>({
    required T Function() email,
    required T Function() msisdn,
  }) =>
      {
        ThirdPartyIdentifierMedium.email: email,
        ThirdPartyIdentifierMedium.msisdn: msisdn,
      }[this]!();
  T maybeWhen<T>({
    T? Function()? email,
    T? Function()? msisdn,
    required T Function() orElse,
  }) =>
      {
        ThirdPartyIdentifierMedium.email: email,
        ThirdPartyIdentifierMedium.msisdn: msisdn,
      }[this]
          ?.call() ??
      orElse();
}

extension IdServerUnbindResultFromStringExtension
    on Iterable<IdServerUnbindResult> {
  IdServerUnbindResult? fromString(String val) {
    final override = {
      'no-support': IdServerUnbindResult.noSupport,
      'success': IdServerUnbindResult.success,
    }[val];
// ignore: unnecessary_this
    return this.contains(override) ? override : null;
  }
}

extension IdServerUnbindResultEnhancedEnum on IdServerUnbindResult {
  @override
// ignore: override_on_non_overriding_member
  String get name => {
        IdServerUnbindResult.noSupport: 'no-support',
        IdServerUnbindResult.success: 'success',
      }[this]!;
  bool get isNoSupport => this == IdServerUnbindResult.noSupport;
  bool get isSuccess => this == IdServerUnbindResult.success;
  T when<T>({
    required T Function() noSupport,
    required T Function() success,
  }) =>
      {
        IdServerUnbindResult.noSupport: noSupport,
        IdServerUnbindResult.success: success,
      }[this]!();
  T maybeWhen<T>({
    T? Function()? noSupport,
    T? Function()? success,
    required T Function() orElse,
  }) =>
      {
        IdServerUnbindResult.noSupport: noSupport,
        IdServerUnbindResult.success: success,
      }[this]
          ?.call() ??
      orElse();
}

extension RoomVersionAvailableFromStringExtension
    on Iterable<RoomVersionAvailable> {
  RoomVersionAvailable? fromString(String val) {
    final override = {
      'stable': RoomVersionAvailable.stable,
      'unstable': RoomVersionAvailable.unstable,
    }[val];
// ignore: unnecessary_this
    return this.contains(override) ? override : null;
  }
}

extension RoomVersionAvailableEnhancedEnum on RoomVersionAvailable {
  @override
// ignore: override_on_non_overriding_member
  String get name => {
        RoomVersionAvailable.stable: 'stable',
        RoomVersionAvailable.unstable: 'unstable',
      }[this]!;
  bool get isStable => this == RoomVersionAvailable.stable;
  bool get isUnstable => this == RoomVersionAvailable.unstable;
  T when<T>({
    required T Function() stable,
    required T Function() unstable,
  }) =>
      {
        RoomVersionAvailable.stable: stable,
        RoomVersionAvailable.unstable: unstable,
      }[this]!();
  T maybeWhen<T>({
    T? Function()? stable,
    T? Function()? unstable,
    required T Function() orElse,
  }) =>
      {
        RoomVersionAvailable.stable: stable,
        RoomVersionAvailable.unstable: unstable,
      }[this]
          ?.call() ??
      orElse();
}

extension CreateRoomPresetFromStringExtension on Iterable<CreateRoomPreset> {
  CreateRoomPreset? fromString(String val) {
    final override = {
      'private_chat': CreateRoomPreset.privateChat,
      'public_chat': CreateRoomPreset.publicChat,
      'trusted_private_chat': CreateRoomPreset.trustedPrivateChat,
    }[val];
// ignore: unnecessary_this
    return this.contains(override) ? override : null;
  }
}

extension CreateRoomPresetEnhancedEnum on CreateRoomPreset {
  @override
// ignore: override_on_non_overriding_member
  String get name => {
        CreateRoomPreset.privateChat: 'private_chat',
        CreateRoomPreset.publicChat: 'public_chat',
        CreateRoomPreset.trustedPrivateChat: 'trusted_private_chat',
      }[this]!;
  bool get isPrivateChat => this == CreateRoomPreset.privateChat;
  bool get isPublicChat => this == CreateRoomPreset.publicChat;
  bool get isTrustedPrivateChat => this == CreateRoomPreset.trustedPrivateChat;
  T when<T>({
    required T Function() privateChat,
    required T Function() publicChat,
    required T Function() trustedPrivateChat,
  }) =>
      {
        CreateRoomPreset.privateChat: privateChat,
        CreateRoomPreset.publicChat: publicChat,
        CreateRoomPreset.trustedPrivateChat: trustedPrivateChat,
      }[this]!();
  T maybeWhen<T>({
    T? Function()? privateChat,
    T? Function()? publicChat,
    T? Function()? trustedPrivateChat,
    required T Function() orElse,
  }) =>
      {
        CreateRoomPreset.privateChat: privateChat,
        CreateRoomPreset.publicChat: publicChat,
        CreateRoomPreset.trustedPrivateChat: trustedPrivateChat,
      }[this]
          ?.call() ??
      orElse();
}

extension VisibilityFromStringExtension on Iterable<Visibility> {
  Visibility? fromString(String val) {
    final override = {
      'private': Visibility.private,
      'public': Visibility.public,
    }[val];
// ignore: unnecessary_this
    return this.contains(override) ? override : null;
  }
}

extension VisibilityEnhancedEnum on Visibility {
  @override
// ignore: override_on_non_overriding_member
  String get name => {
        Visibility.private: 'private',
        Visibility.public: 'public',
      }[this]!;
  bool get isPrivate => this == Visibility.private;
  bool get isPublic => this == Visibility.public;
  T when<T>({
    required T Function() private,
    required T Function() public,
  }) =>
      {
        Visibility.private: private,
        Visibility.public: public,
      }[this]!();
  T maybeWhen<T>({
    T? Function()? private,
    T? Function()? public,
    required T Function() orElse,
  }) =>
      {
        Visibility.private: private,
        Visibility.public: public,
      }[this]
          ?.call() ??
      orElse();
}

extension LoginTypeFromStringExtension on Iterable<LoginType> {
  LoginType? fromString(String val) {
    final override = {
      'm.login.password': LoginType.mLoginPassword,
      'm.login.token': LoginType.mLoginToken,
      'org.matrix.login.jwt': LoginType.mLoginJWT,
    }[val];
// ignore: unnecessary_this
    return this.contains(override) ? override : null;
  }
}

extension LoginTypeEnhancedEnum on LoginType {
  @override
// ignore: override_on_non_overriding_member
  String get name => {
        LoginType.mLoginPassword: 'm.login.password',
        LoginType.mLoginToken: 'm.login.token',
        LoginType.mLoginJWT: 'org.matrix.login.jwt',
      }[this]!;
  bool get isMLoginPassword => this == LoginType.mLoginPassword;
  bool get isMLoginToken => this == LoginType.mLoginToken;
  bool get isMLoginJWT => this == LoginType.mLoginJWT;
  T when<T>({
    required T Function() mLoginPassword,
    required T Function() mLoginToken,
    required T Function() mLoginJWT,
  }) =>
      {
        LoginType.mLoginPassword: mLoginPassword,
        LoginType.mLoginToken: mLoginToken,
        LoginType.mLoginJWT: mLoginJWT,
      }[this]!();
  T maybeWhen<T>({
    T? Function()? mLoginPassword,
    T? Function()? mLoginToken,
    T? Function()? mLoginJWT,
    required T Function() orElse,
  }) =>
      {
        LoginType.mLoginPassword: mLoginPassword,
        LoginType.mLoginToken: mLoginToken,
        LoginType.mLoginJWT: mLoginJWT,
      }[this]
          ?.call() ??
      orElse();
}

extension PresenceTypeFromStringExtension on Iterable<PresenceType> {
  PresenceType? fromString(String val) {
    final override = {
      'offline': PresenceType.offline,
      'online': PresenceType.online,
      'unavailable': PresenceType.unavailable,
    }[val];
// ignore: unnecessary_this
    return this.contains(override) ? override : null;
  }
}

extension PresenceTypeEnhancedEnum on PresenceType {
  @override
// ignore: override_on_non_overriding_member
  String get name => {
        PresenceType.offline: 'offline',
        PresenceType.online: 'online',
        PresenceType.unavailable: 'unavailable',
      }[this]!;
  bool get isOffline => this == PresenceType.offline;
  bool get isOnline => this == PresenceType.online;
  bool get isUnavailable => this == PresenceType.unavailable;
  T when<T>({
    required T Function() offline,
    required T Function() online,
    required T Function() unavailable,
  }) =>
      {
        PresenceType.offline: offline,
        PresenceType.online: online,
        PresenceType.unavailable: unavailable,
      }[this]!();
  T maybeWhen<T>({
    T? Function()? offline,
    T? Function()? online,
    T? Function()? unavailable,
    required T Function() orElse,
  }) =>
      {
        PresenceType.offline: offline,
        PresenceType.online: online,
        PresenceType.unavailable: unavailable,
      }[this]
          ?.call() ??
      orElse();
}

extension PushRuleKindFromStringExtension on Iterable<PushRuleKind> {
  PushRuleKind? fromString(String val) {
    final override = {
      'content': PushRuleKind.content,
      'override': PushRuleKind.override,
      'room': PushRuleKind.room,
      'sender': PushRuleKind.sender,
      'underride': PushRuleKind.underride,
    }[val];
// ignore: unnecessary_this
    return this.contains(override) ? override : null;
  }
}

extension PushRuleKindEnhancedEnum on PushRuleKind {
  @override
// ignore: override_on_non_overriding_member
  String get name => {
        PushRuleKind.content: 'content',
        PushRuleKind.override: 'override',
        PushRuleKind.room: 'room',
        PushRuleKind.sender: 'sender',
        PushRuleKind.underride: 'underride',
      }[this]!;
  bool get isContent => this == PushRuleKind.content;
  bool get isOverride => this == PushRuleKind.override;
  bool get isRoom => this == PushRuleKind.room;
  bool get isSender => this == PushRuleKind.sender;
  bool get isUnderride => this == PushRuleKind.underride;
  T when<T>({
    required T Function() content,
    required T Function() override,
    required T Function() room,
    required T Function() sender,
    required T Function() underride,
  }) =>
      {
        PushRuleKind.content: content,
        PushRuleKind.override: override,
        PushRuleKind.room: room,
        PushRuleKind.sender: sender,
        PushRuleKind.underride: underride,
      }[this]!();
  T maybeWhen<T>({
    T? Function()? content,
    T? Function()? override,
    T? Function()? room,
    T? Function()? sender,
    T? Function()? underride,
    required T Function() orElse,
  }) =>
      {
        PushRuleKind.content: content,
        PushRuleKind.override: override,
        PushRuleKind.room: room,
        PushRuleKind.sender: sender,
        PushRuleKind.underride: underride,
      }[this]
          ?.call() ??
      orElse();
}

extension AccountKindFromStringExtension on Iterable<AccountKind> {
  AccountKind? fromString(String val) {
    final override = {
      'guest': AccountKind.guest,
      'user': AccountKind.user,
    }[val];
// ignore: unnecessary_this
    return this.contains(override) ? override : null;
  }
}

extension AccountKindEnhancedEnum on AccountKind {
  @override
// ignore: override_on_non_overriding_member
  String get name => {
        AccountKind.guest: 'guest',
        AccountKind.user: 'user',
      }[this]!;
  bool get isGuest => this == AccountKind.guest;
  bool get isUser => this == AccountKind.user;
  T when<T>({
    required T Function() guest,
    required T Function() user,
  }) =>
      {
        AccountKind.guest: guest,
        AccountKind.user: user,
      }[this]!();
  T maybeWhen<T>({
    T? Function()? guest,
    T? Function()? user,
    required T Function() orElse,
  }) =>
      {
        AccountKind.guest: guest,
        AccountKind.user: user,
      }[this]
          ?.call() ??
      orElse();
}

extension BackupAlgorithmFromStringExtension on Iterable<BackupAlgorithm> {
  BackupAlgorithm? fromString(String val) {
    final override = {
      'm.megolm_backup.v1.curve25519-aes-sha2':
          BackupAlgorithm.mMegolmBackupV1Curve25519AesSha2,
    }[val];
// ignore: unnecessary_this
    return this.contains(override) ? override : null;
  }
}

extension BackupAlgorithmEnhancedEnum on BackupAlgorithm {
  @override
// ignore: override_on_non_overriding_member
  String get name => {
        BackupAlgorithm.mMegolmBackupV1Curve25519AesSha2:
            'm.megolm_backup.v1.curve25519-aes-sha2',
      }[this]!;
  bool get isMMegolmBackupV1Curve25519AesSha2 =>
      this == BackupAlgorithm.mMegolmBackupV1Curve25519AesSha2;
  T when<T>({
    required T Function() mMegolmBackupV1Curve25519AesSha2,
  }) =>
      {
        BackupAlgorithm.mMegolmBackupV1Curve25519AesSha2:
            mMegolmBackupV1Curve25519AesSha2,
      }[this]!();
  T maybeWhen<T>({
    T? Function()? mMegolmBackupV1Curve25519AesSha2,
    required T Function() orElse,
  }) =>
      {
        BackupAlgorithm.mMegolmBackupV1Curve25519AesSha2:
            mMegolmBackupV1Curve25519AesSha2,
      }[this]
          ?.call() ??
      orElse();
}

extension MembershipFromStringExtension on Iterable<Membership> {
  Membership? fromString(String val) {
    final override = {
      'ban': Membership.ban,
      'invite': Membership.invite,
      'join': Membership.join,
      'knock': Membership.knock,
      'leave': Membership.leave,
    }[val];
// ignore: unnecessary_this
    return this.contains(override) ? override : null;
  }
}

extension MembershipEnhancedEnum on Membership {
  @override
// ignore: override_on_non_overriding_member
  String get name => {
        Membership.ban: 'ban',
        Membership.invite: 'invite',
        Membership.join: 'join',
        Membership.knock: 'knock',
        Membership.leave: 'leave',
      }[this]!;
  bool get isBan => this == Membership.ban;
  bool get isInvite => this == Membership.invite;
  bool get isJoin => this == Membership.join;
  bool get isKnock => this == Membership.knock;
  bool get isLeave => this == Membership.leave;
  T when<T>({
    required T Function() ban,
    required T Function() invite,
    required T Function() join,
    required T Function() knock,
    required T Function() leave,
  }) =>
      {
        Membership.ban: ban,
        Membership.invite: invite,
        Membership.join: join,
        Membership.knock: knock,
        Membership.leave: leave,
      }[this]!();
  T maybeWhen<T>({
    T? Function()? ban,
    T? Function()? invite,
    T? Function()? join,
    T? Function()? knock,
    T? Function()? leave,
    required T Function() orElse,
  }) =>
      {
        Membership.ban: ban,
        Membership.invite: invite,
        Membership.join: join,
        Membership.knock: knock,
        Membership.leave: leave,
      }[this]
          ?.call() ??
      orElse();
}

extension ReceiptTypeFromStringExtension on Iterable<ReceiptType> {
  ReceiptType? fromString(String val) {
    final override = {
      'm.fully_read': ReceiptType.mFullyRead,
      'm.read': ReceiptType.mRead,
      'm.read.private': ReceiptType.mReadPrivate,
    }[val];
// ignore: unnecessary_this
    return this.contains(override) ? override : null;
  }
}

extension ReceiptTypeEnhancedEnum on ReceiptType {
  @override
// ignore: override_on_non_overriding_member
  String get name => {
        ReceiptType.mFullyRead: 'm.fully_read',
        ReceiptType.mRead: 'm.read',
        ReceiptType.mReadPrivate: 'm.read.private',
      }[this]!;
  bool get isMFullyRead => this == ReceiptType.mFullyRead;
  bool get isMRead => this == ReceiptType.mRead;
  bool get isMReadPrivate => this == ReceiptType.mReadPrivate;
  T when<T>({
    required T Function() mFullyRead,
    required T Function() mRead,
    required T Function() mReadPrivate,
  }) =>
      {
        ReceiptType.mFullyRead: mFullyRead,
        ReceiptType.mRead: mRead,
        ReceiptType.mReadPrivate: mReadPrivate,
      }[this]!();
  T maybeWhen<T>({
    T? Function()? mFullyRead,
    T? Function()? mRead,
    T? Function()? mReadPrivate,
    required T Function() orElse,
  }) =>
      {
        ReceiptType.mFullyRead: mFullyRead,
        ReceiptType.mRead: mRead,
        ReceiptType.mReadPrivate: mReadPrivate,
      }[this]
          ?.call() ??
      orElse();
}

extension GroupKeyFromStringExtension on Iterable<GroupKey> {
  GroupKey? fromString(String val) {
    final override = {
      'room_id': GroupKey.roomId,
      'sender': GroupKey.sender,
    }[val];
// ignore: unnecessary_this
    return this.contains(override) ? override : null;
  }
}

extension GroupKeyEnhancedEnum on GroupKey {
  @override
// ignore: override_on_non_overriding_member
  String get name => {
        GroupKey.roomId: 'room_id',
        GroupKey.sender: 'sender',
      }[this]!;
  bool get isRoomId => this == GroupKey.roomId;
  bool get isSender => this == GroupKey.sender;
  T when<T>({
    required T Function() roomId,
    required T Function() sender,
  }) =>
      {
        GroupKey.roomId: roomId,
        GroupKey.sender: sender,
      }[this]!();
  T maybeWhen<T>({
    T? Function()? roomId,
    T? Function()? sender,
    required T Function() orElse,
  }) =>
      {
        GroupKey.roomId: roomId,
        GroupKey.sender: sender,
      }[this]
          ?.call() ??
      orElse();
}

extension KeyKindFromStringExtension on Iterable<KeyKind> {
  KeyKind? fromString(String val) {
    final override = {
      'content.body': KeyKind.contentBody,
      'content.name': KeyKind.contentName,
      'content.topic': KeyKind.contentTopic,
    }[val];
// ignore: unnecessary_this
    return this.contains(override) ? override : null;
  }
}

extension KeyKindEnhancedEnum on KeyKind {
  @override
// ignore: override_on_non_overriding_member
  String get name => {
        KeyKind.contentBody: 'content.body',
        KeyKind.contentName: 'content.name',
        KeyKind.contentTopic: 'content.topic',
      }[this]!;
  bool get isContentBody => this == KeyKind.contentBody;
  bool get isContentName => this == KeyKind.contentName;
  bool get isContentTopic => this == KeyKind.contentTopic;
  T when<T>({
    required T Function() contentBody,
    required T Function() contentName,
    required T Function() contentTopic,
  }) =>
      {
        KeyKind.contentBody: contentBody,
        KeyKind.contentName: contentName,
        KeyKind.contentTopic: contentTopic,
      }[this]!();
  T maybeWhen<T>({
    T? Function()? contentBody,
    T? Function()? contentName,
    T? Function()? contentTopic,
    required T Function() orElse,
  }) =>
      {
        KeyKind.contentBody: contentBody,
        KeyKind.contentName: contentName,
        KeyKind.contentTopic: contentTopic,
      }[this]
          ?.call() ??
      orElse();
}

extension SearchOrderFromStringExtension on Iterable<SearchOrder> {
  SearchOrder? fromString(String val) {
    final override = {
      'rank': SearchOrder.rank,
      'recent': SearchOrder.recent,
    }[val];
// ignore: unnecessary_this
    return this.contains(override) ? override : null;
  }
}

extension SearchOrderEnhancedEnum on SearchOrder {
  @override
// ignore: override_on_non_overriding_member
  String get name => {
        SearchOrder.rank: 'rank',
        SearchOrder.recent: 'recent',
      }[this]!;
  bool get isRank => this == SearchOrder.rank;
  bool get isRecent => this == SearchOrder.recent;
  T when<T>({
    required T Function() rank,
    required T Function() recent,
  }) =>
      {
        SearchOrder.rank: rank,
        SearchOrder.recent: recent,
      }[this]!();
  T maybeWhen<T>({
    T? Function()? rank,
    T? Function()? recent,
    required T Function() orElse,
  }) =>
      {
        SearchOrder.rank: rank,
        SearchOrder.recent: recent,
      }[this]
          ?.call() ??
      orElse();
}

extension EventFormatFromStringExtension on Iterable<EventFormat> {
  EventFormat? fromString(String val) {
    final override = {
      'client': EventFormat.client,
      'federation': EventFormat.federation,
    }[val];
// ignore: unnecessary_this
    return this.contains(override) ? override : null;
  }
}

extension EventFormatEnhancedEnum on EventFormat {
  @override
// ignore: override_on_non_overriding_member
  String get name => {
        EventFormat.client: 'client',
        EventFormat.federation: 'federation',
      }[this]!;
  bool get isClient => this == EventFormat.client;
  bool get isFederation => this == EventFormat.federation;
  T when<T>({
    required T Function() client,
    required T Function() federation,
  }) =>
      {
        EventFormat.client: client,
        EventFormat.federation: federation,
      }[this]!();
  T maybeWhen<T>({
    T? Function()? client,
    T? Function()? federation,
    required T Function() orElse,
  }) =>
      {
        EventFormat.client: client,
        EventFormat.federation: federation,
      }[this]
          ?.call() ??
      orElse();
}

extension MethodFromStringExtension on Iterable<Method> {
  Method? fromString(String val) {
    final override = {
      'crop': Method.crop,
      'scale': Method.scale,
    }[val];
// ignore: unnecessary_this
    return this.contains(override) ? override : null;
  }
}

extension MethodEnhancedEnum on Method {
  @override
// ignore: override_on_non_overriding_member
  String get name => {
        Method.crop: 'crop',
        Method.scale: 'scale',
      }[this]!;
  bool get isCrop => this == Method.crop;
  bool get isScale => this == Method.scale;
  T when<T>({
    required T Function() crop,
    required T Function() scale,
  }) =>
      {
        Method.crop: crop,
        Method.scale: scale,
      }[this]!();
  T maybeWhen<T>({
    T? Function()? crop,
    T? Function()? scale,
    required T Function() orElse,
  }) =>
      {
        Method.crop: crop,
        Method.scale: scale,
      }[this]
          ?.call() ??
      orElse();
}
