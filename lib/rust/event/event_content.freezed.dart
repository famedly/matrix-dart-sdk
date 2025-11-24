// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'event_content.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EventContent {
  Object get field0;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EventContent &&
            const DeepCollectionEquality().equals(other.field0, field0));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(field0));

  @override
  String toString() {
    return 'EventContent(field0: $field0)';
  }
}

/// @nodoc
class $EventContentCopyWith<$Res> {
  $EventContentCopyWith(EventContent _, $Res Function(EventContent) __);
}

/// Adds pattern-matching-related methods to [EventContent].
extension EventContentPatterns on EventContent {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(EventContent_Create value)? create,
    TResult Function(EventContent_Encrypted value)? encrypted,
    TResult Function(EventContent_Encryption value)? encryption,
    TResult Function(EventContent_Member value)? member,
    TResult Function(EventContent_Message value)? message,
    TResult Function(EventContent_BadEncrypted value)? badEncrypted,
    TResult Function(EventContent_MlsCommit value)? mlsCommit,
    TResult Function(EventContent_CallMember value)? callMember,
    TResult Function(EventContent_CallMemberEncryptionKeys value)?
        callMemberEncryptionKeys,
    TResult Function(EventContent_CallMemberEncryptionKeysRequest value)?
        callMemberEncryptionKeysRequest,
    TResult Function(EventContent_CallMemberEncryptionKeysSync value)?
        callMemberEncryptionKeysSync,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case EventContent_Create() when create != null:
        return create(_that);
      case EventContent_Encrypted() when encrypted != null:
        return encrypted(_that);
      case EventContent_Encryption() when encryption != null:
        return encryption(_that);
      case EventContent_Member() when member != null:
        return member(_that);
      case EventContent_Message() when message != null:
        return message(_that);
      case EventContent_BadEncrypted() when badEncrypted != null:
        return badEncrypted(_that);
      case EventContent_MlsCommit() when mlsCommit != null:
        return mlsCommit(_that);
      case EventContent_CallMember() when callMember != null:
        return callMember(_that);
      case EventContent_CallMemberEncryptionKeys()
          when callMemberEncryptionKeys != null:
        return callMemberEncryptionKeys(_that);
      case EventContent_CallMemberEncryptionKeysRequest()
          when callMemberEncryptionKeysRequest != null:
        return callMemberEncryptionKeysRequest(_that);
      case EventContent_CallMemberEncryptionKeysSync()
          when callMemberEncryptionKeysSync != null:
        return callMemberEncryptionKeysSync(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(EventContent_Create value) create,
    required TResult Function(EventContent_Encrypted value) encrypted,
    required TResult Function(EventContent_Encryption value) encryption,
    required TResult Function(EventContent_Member value) member,
    required TResult Function(EventContent_Message value) message,
    required TResult Function(EventContent_BadEncrypted value) badEncrypted,
    required TResult Function(EventContent_MlsCommit value) mlsCommit,
    required TResult Function(EventContent_CallMember value) callMember,
    required TResult Function(EventContent_CallMemberEncryptionKeys value)
        callMemberEncryptionKeys,
    required TResult Function(
            EventContent_CallMemberEncryptionKeysRequest value)
        callMemberEncryptionKeysRequest,
    required TResult Function(EventContent_CallMemberEncryptionKeysSync value)
        callMemberEncryptionKeysSync,
  }) {
    final _that = this;
    switch (_that) {
      case EventContent_Create():
        return create(_that);
      case EventContent_Encrypted():
        return encrypted(_that);
      case EventContent_Encryption():
        return encryption(_that);
      case EventContent_Member():
        return member(_that);
      case EventContent_Message():
        return message(_that);
      case EventContent_BadEncrypted():
        return badEncrypted(_that);
      case EventContent_MlsCommit():
        return mlsCommit(_that);
      case EventContent_CallMember():
        return callMember(_that);
      case EventContent_CallMemberEncryptionKeys():
        return callMemberEncryptionKeys(_that);
      case EventContent_CallMemberEncryptionKeysRequest():
        return callMemberEncryptionKeysRequest(_that);
      case EventContent_CallMemberEncryptionKeysSync():
        return callMemberEncryptionKeysSync(_that);
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(EventContent_Create value)? create,
    TResult? Function(EventContent_Encrypted value)? encrypted,
    TResult? Function(EventContent_Encryption value)? encryption,
    TResult? Function(EventContent_Member value)? member,
    TResult? Function(EventContent_Message value)? message,
    TResult? Function(EventContent_BadEncrypted value)? badEncrypted,
    TResult? Function(EventContent_MlsCommit value)? mlsCommit,
    TResult? Function(EventContent_CallMember value)? callMember,
    TResult? Function(EventContent_CallMemberEncryptionKeys value)?
        callMemberEncryptionKeys,
    TResult? Function(EventContent_CallMemberEncryptionKeysRequest value)?
        callMemberEncryptionKeysRequest,
    TResult? Function(EventContent_CallMemberEncryptionKeysSync value)?
        callMemberEncryptionKeysSync,
  }) {
    final _that = this;
    switch (_that) {
      case EventContent_Create() when create != null:
        return create(_that);
      case EventContent_Encrypted() when encrypted != null:
        return encrypted(_that);
      case EventContent_Encryption() when encryption != null:
        return encryption(_that);
      case EventContent_Member() when member != null:
        return member(_that);
      case EventContent_Message() when message != null:
        return message(_that);
      case EventContent_BadEncrypted() when badEncrypted != null:
        return badEncrypted(_that);
      case EventContent_MlsCommit() when mlsCommit != null:
        return mlsCommit(_that);
      case EventContent_CallMember() when callMember != null:
        return callMember(_that);
      case EventContent_CallMemberEncryptionKeys()
          when callMemberEncryptionKeys != null:
        return callMemberEncryptionKeys(_that);
      case EventContent_CallMemberEncryptionKeysRequest()
          when callMemberEncryptionKeysRequest != null:
        return callMemberEncryptionKeysRequest(_that);
      case EventContent_CallMemberEncryptionKeysSync()
          when callMemberEncryptionKeysSync != null:
        return callMemberEncryptionKeysSync(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(CreateContent field0)? create,
    TResult Function(EncryptedContent field0)? encrypted,
    TResult Function(EncryptionContent field0)? encryption,
    TResult Function(MemberContent field0)? member,
    TResult Function(MessageContent field0)? message,
    TResult Function(MessageContent field0)? badEncrypted,
    TResult Function(MessageContent field0)? mlsCommit,
    TResult Function(MessageContent field0)? callMember,
    TResult Function(MessageContent field0)? callMemberEncryptionKeys,
    TResult Function(MessageContent field0)? callMemberEncryptionKeysRequest,
    TResult Function(MessageContent field0)? callMemberEncryptionKeysSync,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case EventContent_Create() when create != null:
        return create(_that.field0);
      case EventContent_Encrypted() when encrypted != null:
        return encrypted(_that.field0);
      case EventContent_Encryption() when encryption != null:
        return encryption(_that.field0);
      case EventContent_Member() when member != null:
        return member(_that.field0);
      case EventContent_Message() when message != null:
        return message(_that.field0);
      case EventContent_BadEncrypted() when badEncrypted != null:
        return badEncrypted(_that.field0);
      case EventContent_MlsCommit() when mlsCommit != null:
        return mlsCommit(_that.field0);
      case EventContent_CallMember() when callMember != null:
        return callMember(_that.field0);
      case EventContent_CallMemberEncryptionKeys()
          when callMemberEncryptionKeys != null:
        return callMemberEncryptionKeys(_that.field0);
      case EventContent_CallMemberEncryptionKeysRequest()
          when callMemberEncryptionKeysRequest != null:
        return callMemberEncryptionKeysRequest(_that.field0);
      case EventContent_CallMemberEncryptionKeysSync()
          when callMemberEncryptionKeysSync != null:
        return callMemberEncryptionKeysSync(_that.field0);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(CreateContent field0) create,
    required TResult Function(EncryptedContent field0) encrypted,
    required TResult Function(EncryptionContent field0) encryption,
    required TResult Function(MemberContent field0) member,
    required TResult Function(MessageContent field0) message,
    required TResult Function(MessageContent field0) badEncrypted,
    required TResult Function(MessageContent field0) mlsCommit,
    required TResult Function(MessageContent field0) callMember,
    required TResult Function(MessageContent field0) callMemberEncryptionKeys,
    required TResult Function(MessageContent field0)
        callMemberEncryptionKeysRequest,
    required TResult Function(MessageContent field0)
        callMemberEncryptionKeysSync,
  }) {
    final _that = this;
    switch (_that) {
      case EventContent_Create():
        return create(_that.field0);
      case EventContent_Encrypted():
        return encrypted(_that.field0);
      case EventContent_Encryption():
        return encryption(_that.field0);
      case EventContent_Member():
        return member(_that.field0);
      case EventContent_Message():
        return message(_that.field0);
      case EventContent_BadEncrypted():
        return badEncrypted(_that.field0);
      case EventContent_MlsCommit():
        return mlsCommit(_that.field0);
      case EventContent_CallMember():
        return callMember(_that.field0);
      case EventContent_CallMemberEncryptionKeys():
        return callMemberEncryptionKeys(_that.field0);
      case EventContent_CallMemberEncryptionKeysRequest():
        return callMemberEncryptionKeysRequest(_that.field0);
      case EventContent_CallMemberEncryptionKeysSync():
        return callMemberEncryptionKeysSync(_that.field0);
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(CreateContent field0)? create,
    TResult? Function(EncryptedContent field0)? encrypted,
    TResult? Function(EncryptionContent field0)? encryption,
    TResult? Function(MemberContent field0)? member,
    TResult? Function(MessageContent field0)? message,
    TResult? Function(MessageContent field0)? badEncrypted,
    TResult? Function(MessageContent field0)? mlsCommit,
    TResult? Function(MessageContent field0)? callMember,
    TResult? Function(MessageContent field0)? callMemberEncryptionKeys,
    TResult? Function(MessageContent field0)? callMemberEncryptionKeysRequest,
    TResult? Function(MessageContent field0)? callMemberEncryptionKeysSync,
  }) {
    final _that = this;
    switch (_that) {
      case EventContent_Create() when create != null:
        return create(_that.field0);
      case EventContent_Encrypted() when encrypted != null:
        return encrypted(_that.field0);
      case EventContent_Encryption() when encryption != null:
        return encryption(_that.field0);
      case EventContent_Member() when member != null:
        return member(_that.field0);
      case EventContent_Message() when message != null:
        return message(_that.field0);
      case EventContent_BadEncrypted() when badEncrypted != null:
        return badEncrypted(_that.field0);
      case EventContent_MlsCommit() when mlsCommit != null:
        return mlsCommit(_that.field0);
      case EventContent_CallMember() when callMember != null:
        return callMember(_that.field0);
      case EventContent_CallMemberEncryptionKeys()
          when callMemberEncryptionKeys != null:
        return callMemberEncryptionKeys(_that.field0);
      case EventContent_CallMemberEncryptionKeysRequest()
          when callMemberEncryptionKeysRequest != null:
        return callMemberEncryptionKeysRequest(_that.field0);
      case EventContent_CallMemberEncryptionKeysSync()
          when callMemberEncryptionKeysSync != null:
        return callMemberEncryptionKeysSync(_that.field0);
      case _:
        return null;
    }
  }
}

/// @nodoc

class EventContent_Create extends EventContent {
  const EventContent_Create(this.field0) : super._();

  @override
  final CreateContent field0;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EventContent_CreateCopyWith<EventContent_Create> get copyWith =>
      _$EventContent_CreateCopyWithImpl<EventContent_Create>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EventContent_Create &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @override
  String toString() {
    return 'EventContent.create(field0: $field0)';
  }
}

/// @nodoc
abstract mixin class $EventContent_CreateCopyWith<$Res>
    implements $EventContentCopyWith<$Res> {
  factory $EventContent_CreateCopyWith(
          EventContent_Create value, $Res Function(EventContent_Create) _then) =
      _$EventContent_CreateCopyWithImpl;
  @useResult
  $Res call({CreateContent field0});
}

/// @nodoc
class _$EventContent_CreateCopyWithImpl<$Res>
    implements $EventContent_CreateCopyWith<$Res> {
  _$EventContent_CreateCopyWithImpl(this._self, this._then);

  final EventContent_Create _self;
  final $Res Function(EventContent_Create) _then;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? field0 = null,
  }) {
    return _then(EventContent_Create(
      null == field0
          ? _self.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as CreateContent,
    ));
  }
}

/// @nodoc

class EventContent_Encrypted extends EventContent {
  const EventContent_Encrypted(this.field0) : super._();

  @override
  final EncryptedContent field0;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EventContent_EncryptedCopyWith<EventContent_Encrypted> get copyWith =>
      _$EventContent_EncryptedCopyWithImpl<EventContent_Encrypted>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EventContent_Encrypted &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @override
  String toString() {
    return 'EventContent.encrypted(field0: $field0)';
  }
}

/// @nodoc
abstract mixin class $EventContent_EncryptedCopyWith<$Res>
    implements $EventContentCopyWith<$Res> {
  factory $EventContent_EncryptedCopyWith(EventContent_Encrypted value,
          $Res Function(EventContent_Encrypted) _then) =
      _$EventContent_EncryptedCopyWithImpl;
  @useResult
  $Res call({EncryptedContent field0});
}

/// @nodoc
class _$EventContent_EncryptedCopyWithImpl<$Res>
    implements $EventContent_EncryptedCopyWith<$Res> {
  _$EventContent_EncryptedCopyWithImpl(this._self, this._then);

  final EventContent_Encrypted _self;
  final $Res Function(EventContent_Encrypted) _then;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? field0 = null,
  }) {
    return _then(EventContent_Encrypted(
      null == field0
          ? _self.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as EncryptedContent,
    ));
  }
}

/// @nodoc

class EventContent_Encryption extends EventContent {
  const EventContent_Encryption(this.field0) : super._();

  @override
  final EncryptionContent field0;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EventContent_EncryptionCopyWith<EventContent_Encryption> get copyWith =>
      _$EventContent_EncryptionCopyWithImpl<EventContent_Encryption>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EventContent_Encryption &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @override
  String toString() {
    return 'EventContent.encryption(field0: $field0)';
  }
}

/// @nodoc
abstract mixin class $EventContent_EncryptionCopyWith<$Res>
    implements $EventContentCopyWith<$Res> {
  factory $EventContent_EncryptionCopyWith(EventContent_Encryption value,
          $Res Function(EventContent_Encryption) _then) =
      _$EventContent_EncryptionCopyWithImpl;
  @useResult
  $Res call({EncryptionContent field0});
}

/// @nodoc
class _$EventContent_EncryptionCopyWithImpl<$Res>
    implements $EventContent_EncryptionCopyWith<$Res> {
  _$EventContent_EncryptionCopyWithImpl(this._self, this._then);

  final EventContent_Encryption _self;
  final $Res Function(EventContent_Encryption) _then;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? field0 = null,
  }) {
    return _then(EventContent_Encryption(
      null == field0
          ? _self.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as EncryptionContent,
    ));
  }
}

/// @nodoc

class EventContent_Member extends EventContent {
  const EventContent_Member(this.field0) : super._();

  @override
  final MemberContent field0;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EventContent_MemberCopyWith<EventContent_Member> get copyWith =>
      _$EventContent_MemberCopyWithImpl<EventContent_Member>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EventContent_Member &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @override
  String toString() {
    return 'EventContent.member(field0: $field0)';
  }
}

/// @nodoc
abstract mixin class $EventContent_MemberCopyWith<$Res>
    implements $EventContentCopyWith<$Res> {
  factory $EventContent_MemberCopyWith(
          EventContent_Member value, $Res Function(EventContent_Member) _then) =
      _$EventContent_MemberCopyWithImpl;
  @useResult
  $Res call({MemberContent field0});
}

/// @nodoc
class _$EventContent_MemberCopyWithImpl<$Res>
    implements $EventContent_MemberCopyWith<$Res> {
  _$EventContent_MemberCopyWithImpl(this._self, this._then);

  final EventContent_Member _self;
  final $Res Function(EventContent_Member) _then;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? field0 = null,
  }) {
    return _then(EventContent_Member(
      null == field0
          ? _self.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as MemberContent,
    ));
  }
}

/// @nodoc

class EventContent_Message extends EventContent {
  const EventContent_Message(this.field0) : super._();

  @override
  final MessageContent field0;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EventContent_MessageCopyWith<EventContent_Message> get copyWith =>
      _$EventContent_MessageCopyWithImpl<EventContent_Message>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EventContent_Message &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @override
  String toString() {
    return 'EventContent.message(field0: $field0)';
  }
}

/// @nodoc
abstract mixin class $EventContent_MessageCopyWith<$Res>
    implements $EventContentCopyWith<$Res> {
  factory $EventContent_MessageCopyWith(EventContent_Message value,
          $Res Function(EventContent_Message) _then) =
      _$EventContent_MessageCopyWithImpl;
  @useResult
  $Res call({MessageContent field0});

  $MessageContentCopyWith<$Res> get field0;
}

/// @nodoc
class _$EventContent_MessageCopyWithImpl<$Res>
    implements $EventContent_MessageCopyWith<$Res> {
  _$EventContent_MessageCopyWithImpl(this._self, this._then);

  final EventContent_Message _self;
  final $Res Function(EventContent_Message) _then;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? field0 = null,
  }) {
    return _then(EventContent_Message(
      null == field0
          ? _self.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as MessageContent,
    ));
  }

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MessageContentCopyWith<$Res> get field0 {
    return $MessageContentCopyWith<$Res>(_self.field0, (value) {
      return _then(_self.copyWith(field0: value));
    });
  }
}

/// @nodoc

class EventContent_BadEncrypted extends EventContent {
  const EventContent_BadEncrypted(this.field0) : super._();

  @override
  final MessageContent field0;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EventContent_BadEncryptedCopyWith<EventContent_BadEncrypted> get copyWith =>
      _$EventContent_BadEncryptedCopyWithImpl<EventContent_BadEncrypted>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EventContent_BadEncrypted &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @override
  String toString() {
    return 'EventContent.badEncrypted(field0: $field0)';
  }
}

/// @nodoc
abstract mixin class $EventContent_BadEncryptedCopyWith<$Res>
    implements $EventContentCopyWith<$Res> {
  factory $EventContent_BadEncryptedCopyWith(EventContent_BadEncrypted value,
          $Res Function(EventContent_BadEncrypted) _then) =
      _$EventContent_BadEncryptedCopyWithImpl;
  @useResult
  $Res call({MessageContent field0});

  $MessageContentCopyWith<$Res> get field0;
}

/// @nodoc
class _$EventContent_BadEncryptedCopyWithImpl<$Res>
    implements $EventContent_BadEncryptedCopyWith<$Res> {
  _$EventContent_BadEncryptedCopyWithImpl(this._self, this._then);

  final EventContent_BadEncrypted _self;
  final $Res Function(EventContent_BadEncrypted) _then;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? field0 = null,
  }) {
    return _then(EventContent_BadEncrypted(
      null == field0
          ? _self.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as MessageContent,
    ));
  }

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MessageContentCopyWith<$Res> get field0 {
    return $MessageContentCopyWith<$Res>(_self.field0, (value) {
      return _then(_self.copyWith(field0: value));
    });
  }
}

/// @nodoc

class EventContent_MlsCommit extends EventContent {
  const EventContent_MlsCommit(this.field0) : super._();

  @override
  final MessageContent field0;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EventContent_MlsCommitCopyWith<EventContent_MlsCommit> get copyWith =>
      _$EventContent_MlsCommitCopyWithImpl<EventContent_MlsCommit>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EventContent_MlsCommit &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @override
  String toString() {
    return 'EventContent.mlsCommit(field0: $field0)';
  }
}

/// @nodoc
abstract mixin class $EventContent_MlsCommitCopyWith<$Res>
    implements $EventContentCopyWith<$Res> {
  factory $EventContent_MlsCommitCopyWith(EventContent_MlsCommit value,
          $Res Function(EventContent_MlsCommit) _then) =
      _$EventContent_MlsCommitCopyWithImpl;
  @useResult
  $Res call({MessageContent field0});

  $MessageContentCopyWith<$Res> get field0;
}

/// @nodoc
class _$EventContent_MlsCommitCopyWithImpl<$Res>
    implements $EventContent_MlsCommitCopyWith<$Res> {
  _$EventContent_MlsCommitCopyWithImpl(this._self, this._then);

  final EventContent_MlsCommit _self;
  final $Res Function(EventContent_MlsCommit) _then;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? field0 = null,
  }) {
    return _then(EventContent_MlsCommit(
      null == field0
          ? _self.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as MessageContent,
    ));
  }

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MessageContentCopyWith<$Res> get field0 {
    return $MessageContentCopyWith<$Res>(_self.field0, (value) {
      return _then(_self.copyWith(field0: value));
    });
  }
}

/// @nodoc

class EventContent_CallMember extends EventContent {
  const EventContent_CallMember(this.field0) : super._();

  @override
  final MessageContent field0;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EventContent_CallMemberCopyWith<EventContent_CallMember> get copyWith =>
      _$EventContent_CallMemberCopyWithImpl<EventContent_CallMember>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EventContent_CallMember &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @override
  String toString() {
    return 'EventContent.callMember(field0: $field0)';
  }
}

/// @nodoc
abstract mixin class $EventContent_CallMemberCopyWith<$Res>
    implements $EventContentCopyWith<$Res> {
  factory $EventContent_CallMemberCopyWith(EventContent_CallMember value,
          $Res Function(EventContent_CallMember) _then) =
      _$EventContent_CallMemberCopyWithImpl;
  @useResult
  $Res call({MessageContent field0});

  $MessageContentCopyWith<$Res> get field0;
}

/// @nodoc
class _$EventContent_CallMemberCopyWithImpl<$Res>
    implements $EventContent_CallMemberCopyWith<$Res> {
  _$EventContent_CallMemberCopyWithImpl(this._self, this._then);

  final EventContent_CallMember _self;
  final $Res Function(EventContent_CallMember) _then;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? field0 = null,
  }) {
    return _then(EventContent_CallMember(
      null == field0
          ? _self.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as MessageContent,
    ));
  }

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MessageContentCopyWith<$Res> get field0 {
    return $MessageContentCopyWith<$Res>(_self.field0, (value) {
      return _then(_self.copyWith(field0: value));
    });
  }
}

/// @nodoc

class EventContent_CallMemberEncryptionKeys extends EventContent {
  const EventContent_CallMemberEncryptionKeys(this.field0) : super._();

  @override
  final MessageContent field0;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EventContent_CallMemberEncryptionKeysCopyWith<
          EventContent_CallMemberEncryptionKeys>
      get copyWith => _$EventContent_CallMemberEncryptionKeysCopyWithImpl<
          EventContent_CallMemberEncryptionKeys>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EventContent_CallMemberEncryptionKeys &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @override
  String toString() {
    return 'EventContent.callMemberEncryptionKeys(field0: $field0)';
  }
}

/// @nodoc
abstract mixin class $EventContent_CallMemberEncryptionKeysCopyWith<$Res>
    implements $EventContentCopyWith<$Res> {
  factory $EventContent_CallMemberEncryptionKeysCopyWith(
          EventContent_CallMemberEncryptionKeys value,
          $Res Function(EventContent_CallMemberEncryptionKeys) _then) =
      _$EventContent_CallMemberEncryptionKeysCopyWithImpl;
  @useResult
  $Res call({MessageContent field0});

  $MessageContentCopyWith<$Res> get field0;
}

/// @nodoc
class _$EventContent_CallMemberEncryptionKeysCopyWithImpl<$Res>
    implements $EventContent_CallMemberEncryptionKeysCopyWith<$Res> {
  _$EventContent_CallMemberEncryptionKeysCopyWithImpl(this._self, this._then);

  final EventContent_CallMemberEncryptionKeys _self;
  final $Res Function(EventContent_CallMemberEncryptionKeys) _then;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? field0 = null,
  }) {
    return _then(EventContent_CallMemberEncryptionKeys(
      null == field0
          ? _self.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as MessageContent,
    ));
  }

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MessageContentCopyWith<$Res> get field0 {
    return $MessageContentCopyWith<$Res>(_self.field0, (value) {
      return _then(_self.copyWith(field0: value));
    });
  }
}

/// @nodoc

class EventContent_CallMemberEncryptionKeysRequest extends EventContent {
  const EventContent_CallMemberEncryptionKeysRequest(this.field0) : super._();

  @override
  final MessageContent field0;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EventContent_CallMemberEncryptionKeysRequestCopyWith<
          EventContent_CallMemberEncryptionKeysRequest>
      get copyWith =>
          _$EventContent_CallMemberEncryptionKeysRequestCopyWithImpl<
              EventContent_CallMemberEncryptionKeysRequest>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EventContent_CallMemberEncryptionKeysRequest &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @override
  String toString() {
    return 'EventContent.callMemberEncryptionKeysRequest(field0: $field0)';
  }
}

/// @nodoc
abstract mixin class $EventContent_CallMemberEncryptionKeysRequestCopyWith<$Res>
    implements $EventContentCopyWith<$Res> {
  factory $EventContent_CallMemberEncryptionKeysRequestCopyWith(
          EventContent_CallMemberEncryptionKeysRequest value,
          $Res Function(EventContent_CallMemberEncryptionKeysRequest) _then) =
      _$EventContent_CallMemberEncryptionKeysRequestCopyWithImpl;
  @useResult
  $Res call({MessageContent field0});

  $MessageContentCopyWith<$Res> get field0;
}

/// @nodoc
class _$EventContent_CallMemberEncryptionKeysRequestCopyWithImpl<$Res>
    implements $EventContent_CallMemberEncryptionKeysRequestCopyWith<$Res> {
  _$EventContent_CallMemberEncryptionKeysRequestCopyWithImpl(
      this._self, this._then);

  final EventContent_CallMemberEncryptionKeysRequest _self;
  final $Res Function(EventContent_CallMemberEncryptionKeysRequest) _then;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? field0 = null,
  }) {
    return _then(EventContent_CallMemberEncryptionKeysRequest(
      null == field0
          ? _self.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as MessageContent,
    ));
  }

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MessageContentCopyWith<$Res> get field0 {
    return $MessageContentCopyWith<$Res>(_self.field0, (value) {
      return _then(_self.copyWith(field0: value));
    });
  }
}

/// @nodoc

class EventContent_CallMemberEncryptionKeysSync extends EventContent {
  const EventContent_CallMemberEncryptionKeysSync(this.field0) : super._();

  @override
  final MessageContent field0;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EventContent_CallMemberEncryptionKeysSyncCopyWith<
          EventContent_CallMemberEncryptionKeysSync>
      get copyWith => _$EventContent_CallMemberEncryptionKeysSyncCopyWithImpl<
          EventContent_CallMemberEncryptionKeysSync>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EventContent_CallMemberEncryptionKeysSync &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @override
  String toString() {
    return 'EventContent.callMemberEncryptionKeysSync(field0: $field0)';
  }
}

/// @nodoc
abstract mixin class $EventContent_CallMemberEncryptionKeysSyncCopyWith<$Res>
    implements $EventContentCopyWith<$Res> {
  factory $EventContent_CallMemberEncryptionKeysSyncCopyWith(
          EventContent_CallMemberEncryptionKeysSync value,
          $Res Function(EventContent_CallMemberEncryptionKeysSync) _then) =
      _$EventContent_CallMemberEncryptionKeysSyncCopyWithImpl;
  @useResult
  $Res call({MessageContent field0});

  $MessageContentCopyWith<$Res> get field0;
}

/// @nodoc
class _$EventContent_CallMemberEncryptionKeysSyncCopyWithImpl<$Res>
    implements $EventContent_CallMemberEncryptionKeysSyncCopyWith<$Res> {
  _$EventContent_CallMemberEncryptionKeysSyncCopyWithImpl(
      this._self, this._then);

  final EventContent_CallMemberEncryptionKeysSync _self;
  final $Res Function(EventContent_CallMemberEncryptionKeysSync) _then;

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? field0 = null,
  }) {
    return _then(EventContent_CallMemberEncryptionKeysSync(
      null == field0
          ? _self.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as MessageContent,
    ));
  }

  /// Create a copy of EventContent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MessageContentCopyWith<$Res> get field0 {
    return $MessageContentCopyWith<$Res>(_self.field0, (value) {
      return _then(_self.copyWith(field0: value));
    });
  }
}

/// @nodoc
mixin _$MessageContent {
  Object get body;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MessageContent &&
            const DeepCollectionEquality().equals(other.body, body));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(body));

  @override
  String toString() {
    return 'MessageContent(body: $body)';
  }
}

/// @nodoc
class $MessageContentCopyWith<$Res> {
  $MessageContentCopyWith(MessageContent _, $Res Function(MessageContent) __);
}

/// Adds pattern-matching-related methods to [MessageContent].
extension MessageContentPatterns on MessageContent {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageContent_CallEncryptionKeys value)?
        callEncryptionKeys,
    TResult Function(MessageContent_Text value)? text,
    TResult Function(MessageContent_Image value)? image,
    TResult Function(MessageContent_Video value)? video,
    TResult Function(MessageContent_Sticker value)? sticker,
    TResult Function(MessageContent_Audio value)? audio,
    TResult Function(MessageContent_Notice value)? notice,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case MessageContent_CallEncryptionKeys() when callEncryptionKeys != null:
        return callEncryptionKeys(_that);
      case MessageContent_Text() when text != null:
        return text(_that);
      case MessageContent_Image() when image != null:
        return image(_that);
      case MessageContent_Video() when video != null:
        return video(_that);
      case MessageContent_Sticker() when sticker != null:
        return sticker(_that);
      case MessageContent_Audio() when audio != null:
        return audio(_that);
      case MessageContent_Notice() when notice != null:
        return notice(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageContent_CallEncryptionKeys value)
        callEncryptionKeys,
    required TResult Function(MessageContent_Text value) text,
    required TResult Function(MessageContent_Image value) image,
    required TResult Function(MessageContent_Video value) video,
    required TResult Function(MessageContent_Sticker value) sticker,
    required TResult Function(MessageContent_Audio value) audio,
    required TResult Function(MessageContent_Notice value) notice,
  }) {
    final _that = this;
    switch (_that) {
      case MessageContent_CallEncryptionKeys():
        return callEncryptionKeys(_that);
      case MessageContent_Text():
        return text(_that);
      case MessageContent_Image():
        return image(_that);
      case MessageContent_Video():
        return video(_that);
      case MessageContent_Sticker():
        return sticker(_that);
      case MessageContent_Audio():
        return audio(_that);
      case MessageContent_Notice():
        return notice(_that);
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageContent_CallEncryptionKeys value)?
        callEncryptionKeys,
    TResult? Function(MessageContent_Text value)? text,
    TResult? Function(MessageContent_Image value)? image,
    TResult? Function(MessageContent_Video value)? video,
    TResult? Function(MessageContent_Sticker value)? sticker,
    TResult? Function(MessageContent_Audio value)? audio,
    TResult? Function(MessageContent_Notice value)? notice,
  }) {
    final _that = this;
    switch (_that) {
      case MessageContent_CallEncryptionKeys() when callEncryptionKeys != null:
        return callEncryptionKeys(_that);
      case MessageContent_Text() when text != null:
        return text(_that);
      case MessageContent_Image() when image != null:
        return image(_that);
      case MessageContent_Video() when video != null:
        return video(_that);
      case MessageContent_Sticker() when sticker != null:
        return sticker(_that);
      case MessageContent_Audio() when audio != null:
        return audio(_that);
      case MessageContent_Notice() when notice != null:
        return notice(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Map<String, Value?> body)? callEncryptionKeys,
    TResult Function(String body)? text,
    TResult Function(String body)? image,
    TResult Function(String body)? video,
    TResult Function(String body)? sticker,
    TResult Function(String body)? audio,
    TResult Function(String body)? notice,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case MessageContent_CallEncryptionKeys() when callEncryptionKeys != null:
        return callEncryptionKeys(_that.body);
      case MessageContent_Text() when text != null:
        return text(_that.body);
      case MessageContent_Image() when image != null:
        return image(_that.body);
      case MessageContent_Video() when video != null:
        return video(_that.body);
      case MessageContent_Sticker() when sticker != null:
        return sticker(_that.body);
      case MessageContent_Audio() when audio != null:
        return audio(_that.body);
      case MessageContent_Notice() when notice != null:
        return notice(_that.body);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Map<String, Value?> body) callEncryptionKeys,
    required TResult Function(String body) text,
    required TResult Function(String body) image,
    required TResult Function(String body) video,
    required TResult Function(String body) sticker,
    required TResult Function(String body) audio,
    required TResult Function(String body) notice,
  }) {
    final _that = this;
    switch (_that) {
      case MessageContent_CallEncryptionKeys():
        return callEncryptionKeys(_that.body);
      case MessageContent_Text():
        return text(_that.body);
      case MessageContent_Image():
        return image(_that.body);
      case MessageContent_Video():
        return video(_that.body);
      case MessageContent_Sticker():
        return sticker(_that.body);
      case MessageContent_Audio():
        return audio(_that.body);
      case MessageContent_Notice():
        return notice(_that.body);
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Map<String, Value?> body)? callEncryptionKeys,
    TResult? Function(String body)? text,
    TResult? Function(String body)? image,
    TResult? Function(String body)? video,
    TResult? Function(String body)? sticker,
    TResult? Function(String body)? audio,
    TResult? Function(String body)? notice,
  }) {
    final _that = this;
    switch (_that) {
      case MessageContent_CallEncryptionKeys() when callEncryptionKeys != null:
        return callEncryptionKeys(_that.body);
      case MessageContent_Text() when text != null:
        return text(_that.body);
      case MessageContent_Image() when image != null:
        return image(_that.body);
      case MessageContent_Video() when video != null:
        return video(_that.body);
      case MessageContent_Sticker() when sticker != null:
        return sticker(_that.body);
      case MessageContent_Audio() when audio != null:
        return audio(_that.body);
      case MessageContent_Notice() when notice != null:
        return notice(_that.body);
      case _:
        return null;
    }
  }
}

/// @nodoc

class MessageContent_CallEncryptionKeys extends MessageContent {
  const MessageContent_CallEncryptionKeys(
      {required final Map<String, Value?> body})
      : _body = body,
        super._();

  final Map<String, Value?> _body;
  @override
  Map<String, Value?> get body {
    if (_body is EqualUnmodifiableMapView) return _body;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_body);
  }

  /// Create a copy of MessageContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MessageContent_CallEncryptionKeysCopyWith<MessageContent_CallEncryptionKeys>
      get copyWith => _$MessageContent_CallEncryptionKeysCopyWithImpl<
          MessageContent_CallEncryptionKeys>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MessageContent_CallEncryptionKeys &&
            const DeepCollectionEquality().equals(other._body, _body));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_body));

  @override
  String toString() {
    return 'MessageContent.callEncryptionKeys(body: $body)';
  }
}

/// @nodoc
abstract mixin class $MessageContent_CallEncryptionKeysCopyWith<$Res>
    implements $MessageContentCopyWith<$Res> {
  factory $MessageContent_CallEncryptionKeysCopyWith(
          MessageContent_CallEncryptionKeys value,
          $Res Function(MessageContent_CallEncryptionKeys) _then) =
      _$MessageContent_CallEncryptionKeysCopyWithImpl;
  @useResult
  $Res call({Map<String, Value?> body});
}

/// @nodoc
class _$MessageContent_CallEncryptionKeysCopyWithImpl<$Res>
    implements $MessageContent_CallEncryptionKeysCopyWith<$Res> {
  _$MessageContent_CallEncryptionKeysCopyWithImpl(this._self, this._then);

  final MessageContent_CallEncryptionKeys _self;
  final $Res Function(MessageContent_CallEncryptionKeys) _then;

  /// Create a copy of MessageContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? body = null,
  }) {
    return _then(MessageContent_CallEncryptionKeys(
      body: null == body
          ? _self._body
          : body // ignore: cast_nullable_to_non_nullable
              as Map<String, Value?>,
    ));
  }
}

/// @nodoc

class MessageContent_Text extends MessageContent {
  const MessageContent_Text({required this.body}) : super._();

  @override
  final String body;

  /// Create a copy of MessageContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MessageContent_TextCopyWith<MessageContent_Text> get copyWith =>
      _$MessageContent_TextCopyWithImpl<MessageContent_Text>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MessageContent_Text &&
            (identical(other.body, body) || other.body == body));
  }

  @override
  int get hashCode => Object.hash(runtimeType, body);

  @override
  String toString() {
    return 'MessageContent.text(body: $body)';
  }
}

/// @nodoc
abstract mixin class $MessageContent_TextCopyWith<$Res>
    implements $MessageContentCopyWith<$Res> {
  factory $MessageContent_TextCopyWith(
          MessageContent_Text value, $Res Function(MessageContent_Text) _then) =
      _$MessageContent_TextCopyWithImpl;
  @useResult
  $Res call({String body});
}

/// @nodoc
class _$MessageContent_TextCopyWithImpl<$Res>
    implements $MessageContent_TextCopyWith<$Res> {
  _$MessageContent_TextCopyWithImpl(this._self, this._then);

  final MessageContent_Text _self;
  final $Res Function(MessageContent_Text) _then;

  /// Create a copy of MessageContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? body = null,
  }) {
    return _then(MessageContent_Text(
      body: null == body
          ? _self.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class MessageContent_Image extends MessageContent {
  const MessageContent_Image({required this.body}) : super._();

  @override
  final String body;

  /// Create a copy of MessageContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MessageContent_ImageCopyWith<MessageContent_Image> get copyWith =>
      _$MessageContent_ImageCopyWithImpl<MessageContent_Image>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MessageContent_Image &&
            (identical(other.body, body) || other.body == body));
  }

  @override
  int get hashCode => Object.hash(runtimeType, body);

  @override
  String toString() {
    return 'MessageContent.image(body: $body)';
  }
}

/// @nodoc
abstract mixin class $MessageContent_ImageCopyWith<$Res>
    implements $MessageContentCopyWith<$Res> {
  factory $MessageContent_ImageCopyWith(MessageContent_Image value,
          $Res Function(MessageContent_Image) _then) =
      _$MessageContent_ImageCopyWithImpl;
  @useResult
  $Res call({String body});
}

/// @nodoc
class _$MessageContent_ImageCopyWithImpl<$Res>
    implements $MessageContent_ImageCopyWith<$Res> {
  _$MessageContent_ImageCopyWithImpl(this._self, this._then);

  final MessageContent_Image _self;
  final $Res Function(MessageContent_Image) _then;

  /// Create a copy of MessageContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? body = null,
  }) {
    return _then(MessageContent_Image(
      body: null == body
          ? _self.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class MessageContent_Video extends MessageContent {
  const MessageContent_Video({required this.body}) : super._();

  @override
  final String body;

  /// Create a copy of MessageContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MessageContent_VideoCopyWith<MessageContent_Video> get copyWith =>
      _$MessageContent_VideoCopyWithImpl<MessageContent_Video>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MessageContent_Video &&
            (identical(other.body, body) || other.body == body));
  }

  @override
  int get hashCode => Object.hash(runtimeType, body);

  @override
  String toString() {
    return 'MessageContent.video(body: $body)';
  }
}

/// @nodoc
abstract mixin class $MessageContent_VideoCopyWith<$Res>
    implements $MessageContentCopyWith<$Res> {
  factory $MessageContent_VideoCopyWith(MessageContent_Video value,
          $Res Function(MessageContent_Video) _then) =
      _$MessageContent_VideoCopyWithImpl;
  @useResult
  $Res call({String body});
}

/// @nodoc
class _$MessageContent_VideoCopyWithImpl<$Res>
    implements $MessageContent_VideoCopyWith<$Res> {
  _$MessageContent_VideoCopyWithImpl(this._self, this._then);

  final MessageContent_Video _self;
  final $Res Function(MessageContent_Video) _then;

  /// Create a copy of MessageContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? body = null,
  }) {
    return _then(MessageContent_Video(
      body: null == body
          ? _self.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class MessageContent_Sticker extends MessageContent {
  const MessageContent_Sticker({required this.body}) : super._();

  @override
  final String body;

  /// Create a copy of MessageContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MessageContent_StickerCopyWith<MessageContent_Sticker> get copyWith =>
      _$MessageContent_StickerCopyWithImpl<MessageContent_Sticker>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MessageContent_Sticker &&
            (identical(other.body, body) || other.body == body));
  }

  @override
  int get hashCode => Object.hash(runtimeType, body);

  @override
  String toString() {
    return 'MessageContent.sticker(body: $body)';
  }
}

/// @nodoc
abstract mixin class $MessageContent_StickerCopyWith<$Res>
    implements $MessageContentCopyWith<$Res> {
  factory $MessageContent_StickerCopyWith(MessageContent_Sticker value,
          $Res Function(MessageContent_Sticker) _then) =
      _$MessageContent_StickerCopyWithImpl;
  @useResult
  $Res call({String body});
}

/// @nodoc
class _$MessageContent_StickerCopyWithImpl<$Res>
    implements $MessageContent_StickerCopyWith<$Res> {
  _$MessageContent_StickerCopyWithImpl(this._self, this._then);

  final MessageContent_Sticker _self;
  final $Res Function(MessageContent_Sticker) _then;

  /// Create a copy of MessageContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? body = null,
  }) {
    return _then(MessageContent_Sticker(
      body: null == body
          ? _self.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class MessageContent_Audio extends MessageContent {
  const MessageContent_Audio({required this.body}) : super._();

  @override
  final String body;

  /// Create a copy of MessageContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MessageContent_AudioCopyWith<MessageContent_Audio> get copyWith =>
      _$MessageContent_AudioCopyWithImpl<MessageContent_Audio>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MessageContent_Audio &&
            (identical(other.body, body) || other.body == body));
  }

  @override
  int get hashCode => Object.hash(runtimeType, body);

  @override
  String toString() {
    return 'MessageContent.audio(body: $body)';
  }
}

/// @nodoc
abstract mixin class $MessageContent_AudioCopyWith<$Res>
    implements $MessageContentCopyWith<$Res> {
  factory $MessageContent_AudioCopyWith(MessageContent_Audio value,
          $Res Function(MessageContent_Audio) _then) =
      _$MessageContent_AudioCopyWithImpl;
  @useResult
  $Res call({String body});
}

/// @nodoc
class _$MessageContent_AudioCopyWithImpl<$Res>
    implements $MessageContent_AudioCopyWith<$Res> {
  _$MessageContent_AudioCopyWithImpl(this._self, this._then);

  final MessageContent_Audio _self;
  final $Res Function(MessageContent_Audio) _then;

  /// Create a copy of MessageContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? body = null,
  }) {
    return _then(MessageContent_Audio(
      body: null == body
          ? _self.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class MessageContent_Notice extends MessageContent {
  const MessageContent_Notice({required this.body}) : super._();

  @override
  final String body;

  /// Create a copy of MessageContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MessageContent_NoticeCopyWith<MessageContent_Notice> get copyWith =>
      _$MessageContent_NoticeCopyWithImpl<MessageContent_Notice>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MessageContent_Notice &&
            (identical(other.body, body) || other.body == body));
  }

  @override
  int get hashCode => Object.hash(runtimeType, body);

  @override
  String toString() {
    return 'MessageContent.notice(body: $body)';
  }
}

/// @nodoc
abstract mixin class $MessageContent_NoticeCopyWith<$Res>
    implements $MessageContentCopyWith<$Res> {
  factory $MessageContent_NoticeCopyWith(MessageContent_Notice value,
          $Res Function(MessageContent_Notice) _then) =
      _$MessageContent_NoticeCopyWithImpl;
  @useResult
  $Res call({String body});
}

/// @nodoc
class _$MessageContent_NoticeCopyWithImpl<$Res>
    implements $MessageContent_NoticeCopyWith<$Res> {
  _$MessageContent_NoticeCopyWithImpl(this._self, this._then);

  final MessageContent_Notice _self;
  final $Res Function(MessageContent_Notice) _then;

  /// Create a copy of MessageContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? body = null,
  }) {
    return _then(MessageContent_Notice(
      body: null == body
          ? _self.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
