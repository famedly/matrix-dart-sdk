// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mls_crypto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DecryptedMessage {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is DecryptedMessage);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'DecryptedMessage()';
  }
}

/// @nodoc
class $DecryptedMessageCopyWith<$Res> {
  $DecryptedMessageCopyWith(
      DecryptedMessage _, $Res Function(DecryptedMessage) __);
}

/// Adds pattern-matching-related methods to [DecryptedMessage].
extension DecryptedMessagePatterns on DecryptedMessage {
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
    TResult Function(DecryptedMessage_WelcomeMessage value)? welcomeMessage,
    TResult Function(DecryptedMessage_StagedCommitMessage value)?
        stagedCommitMessage,
    TResult Function(DecryptedMessage_Proposal value)? proposal,
    TResult Function(DecryptedMessage_Message value)? message,
    TResult Function(DecryptedMessage_Unimplemented value)? unimplemented,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case DecryptedMessage_WelcomeMessage() when welcomeMessage != null:
        return welcomeMessage(_that);
      case DecryptedMessage_StagedCommitMessage()
          when stagedCommitMessage != null:
        return stagedCommitMessage(_that);
      case DecryptedMessage_Proposal() when proposal != null:
        return proposal(_that);
      case DecryptedMessage_Message() when message != null:
        return message(_that);
      case DecryptedMessage_Unimplemented() when unimplemented != null:
        return unimplemented(_that);
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
    required TResult Function(DecryptedMessage_WelcomeMessage value)
        welcomeMessage,
    required TResult Function(DecryptedMessage_StagedCommitMessage value)
        stagedCommitMessage,
    required TResult Function(DecryptedMessage_Proposal value) proposal,
    required TResult Function(DecryptedMessage_Message value) message,
    required TResult Function(DecryptedMessage_Unimplemented value)
        unimplemented,
  }) {
    final _that = this;
    switch (_that) {
      case DecryptedMessage_WelcomeMessage():
        return welcomeMessage(_that);
      case DecryptedMessage_StagedCommitMessage():
        return stagedCommitMessage(_that);
      case DecryptedMessage_Proposal():
        return proposal(_that);
      case DecryptedMessage_Message():
        return message(_that);
      case DecryptedMessage_Unimplemented():
        return unimplemented(_that);
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
    TResult? Function(DecryptedMessage_WelcomeMessage value)? welcomeMessage,
    TResult? Function(DecryptedMessage_StagedCommitMessage value)?
        stagedCommitMessage,
    TResult? Function(DecryptedMessage_Proposal value)? proposal,
    TResult? Function(DecryptedMessage_Message value)? message,
    TResult? Function(DecryptedMessage_Unimplemented value)? unimplemented,
  }) {
    final _that = this;
    switch (_that) {
      case DecryptedMessage_WelcomeMessage() when welcomeMessage != null:
        return welcomeMessage(_that);
      case DecryptedMessage_StagedCommitMessage()
          when stagedCommitMessage != null:
        return stagedCommitMessage(_that);
      case DecryptedMessage_Proposal() when proposal != null:
        return proposal(_that);
      case DecryptedMessage_Message() when message != null:
        return message(_that);
      case DecryptedMessage_Unimplemented() when unimplemented != null:
        return unimplemented(_that);
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
    TResult Function(String groupId)? welcomeMessage,
    TResult Function(String? senderName)? stagedCommitMessage,
    TResult Function(String? senderName, String message)? proposal,
    TResult Function(String? senderName, String message)? message,
    TResult Function()? unimplemented,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case DecryptedMessage_WelcomeMessage() when welcomeMessage != null:
        return welcomeMessage(_that.groupId);
      case DecryptedMessage_StagedCommitMessage()
          when stagedCommitMessage != null:
        return stagedCommitMessage(_that.senderName);
      case DecryptedMessage_Proposal() when proposal != null:
        return proposal(_that.senderName, _that.message);
      case DecryptedMessage_Message() when message != null:
        return message(_that.senderName, _that.message);
      case DecryptedMessage_Unimplemented() when unimplemented != null:
        return unimplemented();
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
    required TResult Function(String groupId) welcomeMessage,
    required TResult Function(String? senderName) stagedCommitMessage,
    required TResult Function(String? senderName, String message) proposal,
    required TResult Function(String? senderName, String message) message,
    required TResult Function() unimplemented,
  }) {
    final _that = this;
    switch (_that) {
      case DecryptedMessage_WelcomeMessage():
        return welcomeMessage(_that.groupId);
      case DecryptedMessage_StagedCommitMessage():
        return stagedCommitMessage(_that.senderName);
      case DecryptedMessage_Proposal():
        return proposal(_that.senderName, _that.message);
      case DecryptedMessage_Message():
        return message(_that.senderName, _that.message);
      case DecryptedMessage_Unimplemented():
        return unimplemented();
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
    TResult? Function(String groupId)? welcomeMessage,
    TResult? Function(String? senderName)? stagedCommitMessage,
    TResult? Function(String? senderName, String message)? proposal,
    TResult? Function(String? senderName, String message)? message,
    TResult? Function()? unimplemented,
  }) {
    final _that = this;
    switch (_that) {
      case DecryptedMessage_WelcomeMessage() when welcomeMessage != null:
        return welcomeMessage(_that.groupId);
      case DecryptedMessage_StagedCommitMessage()
          when stagedCommitMessage != null:
        return stagedCommitMessage(_that.senderName);
      case DecryptedMessage_Proposal() when proposal != null:
        return proposal(_that.senderName, _that.message);
      case DecryptedMessage_Message() when message != null:
        return message(_that.senderName, _that.message);
      case DecryptedMessage_Unimplemented() when unimplemented != null:
        return unimplemented();
      case _:
        return null;
    }
  }
}

/// @nodoc

class DecryptedMessage_WelcomeMessage extends DecryptedMessage {
  const DecryptedMessage_WelcomeMessage({required this.groupId}) : super._();

  final String groupId;

  /// Create a copy of DecryptedMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DecryptedMessage_WelcomeMessageCopyWith<DecryptedMessage_WelcomeMessage>
      get copyWith => _$DecryptedMessage_WelcomeMessageCopyWithImpl<
          DecryptedMessage_WelcomeMessage>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DecryptedMessage_WelcomeMessage &&
            (identical(other.groupId, groupId) || other.groupId == groupId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, groupId);

  @override
  String toString() {
    return 'DecryptedMessage.welcomeMessage(groupId: $groupId)';
  }
}

/// @nodoc
abstract mixin class $DecryptedMessage_WelcomeMessageCopyWith<$Res>
    implements $DecryptedMessageCopyWith<$Res> {
  factory $DecryptedMessage_WelcomeMessageCopyWith(
          DecryptedMessage_WelcomeMessage value,
          $Res Function(DecryptedMessage_WelcomeMessage) _then) =
      _$DecryptedMessage_WelcomeMessageCopyWithImpl;
  @useResult
  $Res call({String groupId});
}

/// @nodoc
class _$DecryptedMessage_WelcomeMessageCopyWithImpl<$Res>
    implements $DecryptedMessage_WelcomeMessageCopyWith<$Res> {
  _$DecryptedMessage_WelcomeMessageCopyWithImpl(this._self, this._then);

  final DecryptedMessage_WelcomeMessage _self;
  final $Res Function(DecryptedMessage_WelcomeMessage) _then;

  /// Create a copy of DecryptedMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? groupId = null,
  }) {
    return _then(DecryptedMessage_WelcomeMessage(
      groupId: null == groupId
          ? _self.groupId
          : groupId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class DecryptedMessage_StagedCommitMessage extends DecryptedMessage {
  const DecryptedMessage_StagedCommitMessage({this.senderName}) : super._();

  final String? senderName;

  /// Create a copy of DecryptedMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DecryptedMessage_StagedCommitMessageCopyWith<
          DecryptedMessage_StagedCommitMessage>
      get copyWith => _$DecryptedMessage_StagedCommitMessageCopyWithImpl<
          DecryptedMessage_StagedCommitMessage>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DecryptedMessage_StagedCommitMessage &&
            (identical(other.senderName, senderName) ||
                other.senderName == senderName));
  }

  @override
  int get hashCode => Object.hash(runtimeType, senderName);

  @override
  String toString() {
    return 'DecryptedMessage.stagedCommitMessage(senderName: $senderName)';
  }
}

/// @nodoc
abstract mixin class $DecryptedMessage_StagedCommitMessageCopyWith<$Res>
    implements $DecryptedMessageCopyWith<$Res> {
  factory $DecryptedMessage_StagedCommitMessageCopyWith(
          DecryptedMessage_StagedCommitMessage value,
          $Res Function(DecryptedMessage_StagedCommitMessage) _then) =
      _$DecryptedMessage_StagedCommitMessageCopyWithImpl;
  @useResult
  $Res call({String? senderName});
}

/// @nodoc
class _$DecryptedMessage_StagedCommitMessageCopyWithImpl<$Res>
    implements $DecryptedMessage_StagedCommitMessageCopyWith<$Res> {
  _$DecryptedMessage_StagedCommitMessageCopyWithImpl(this._self, this._then);

  final DecryptedMessage_StagedCommitMessage _self;
  final $Res Function(DecryptedMessage_StagedCommitMessage) _then;

  /// Create a copy of DecryptedMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? senderName = freezed,
  }) {
    return _then(DecryptedMessage_StagedCommitMessage(
      senderName: freezed == senderName
          ? _self.senderName
          : senderName // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class DecryptedMessage_Proposal extends DecryptedMessage {
  const DecryptedMessage_Proposal({this.senderName, required this.message})
      : super._();

  final String? senderName;
  final String message;

  /// Create a copy of DecryptedMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DecryptedMessage_ProposalCopyWith<DecryptedMessage_Proposal> get copyWith =>
      _$DecryptedMessage_ProposalCopyWithImpl<DecryptedMessage_Proposal>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DecryptedMessage_Proposal &&
            (identical(other.senderName, senderName) ||
                other.senderName == senderName) &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, senderName, message);

  @override
  String toString() {
    return 'DecryptedMessage.proposal(senderName: $senderName, message: $message)';
  }
}

/// @nodoc
abstract mixin class $DecryptedMessage_ProposalCopyWith<$Res>
    implements $DecryptedMessageCopyWith<$Res> {
  factory $DecryptedMessage_ProposalCopyWith(DecryptedMessage_Proposal value,
          $Res Function(DecryptedMessage_Proposal) _then) =
      _$DecryptedMessage_ProposalCopyWithImpl;
  @useResult
  $Res call({String? senderName, String message});
}

/// @nodoc
class _$DecryptedMessage_ProposalCopyWithImpl<$Res>
    implements $DecryptedMessage_ProposalCopyWith<$Res> {
  _$DecryptedMessage_ProposalCopyWithImpl(this._self, this._then);

  final DecryptedMessage_Proposal _self;
  final $Res Function(DecryptedMessage_Proposal) _then;

  /// Create a copy of DecryptedMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? senderName = freezed,
    Object? message = null,
  }) {
    return _then(DecryptedMessage_Proposal(
      senderName: freezed == senderName
          ? _self.senderName
          : senderName // ignore: cast_nullable_to_non_nullable
              as String?,
      message: null == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class DecryptedMessage_Message extends DecryptedMessage {
  const DecryptedMessage_Message({this.senderName, required this.message})
      : super._();

  final String? senderName;
  final String message;

  /// Create a copy of DecryptedMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DecryptedMessage_MessageCopyWith<DecryptedMessage_Message> get copyWith =>
      _$DecryptedMessage_MessageCopyWithImpl<DecryptedMessage_Message>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DecryptedMessage_Message &&
            (identical(other.senderName, senderName) ||
                other.senderName == senderName) &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, senderName, message);

  @override
  String toString() {
    return 'DecryptedMessage.message(senderName: $senderName, message: $message)';
  }
}

/// @nodoc
abstract mixin class $DecryptedMessage_MessageCopyWith<$Res>
    implements $DecryptedMessageCopyWith<$Res> {
  factory $DecryptedMessage_MessageCopyWith(DecryptedMessage_Message value,
          $Res Function(DecryptedMessage_Message) _then) =
      _$DecryptedMessage_MessageCopyWithImpl;
  @useResult
  $Res call({String? senderName, String message});
}

/// @nodoc
class _$DecryptedMessage_MessageCopyWithImpl<$Res>
    implements $DecryptedMessage_MessageCopyWith<$Res> {
  _$DecryptedMessage_MessageCopyWithImpl(this._self, this._then);

  final DecryptedMessage_Message _self;
  final $Res Function(DecryptedMessage_Message) _then;

  /// Create a copy of DecryptedMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? senderName = freezed,
    Object? message = null,
  }) {
    return _then(DecryptedMessage_Message(
      senderName: freezed == senderName
          ? _self.senderName
          : senderName // ignore: cast_nullable_to_non_nullable
              as String?,
      message: null == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class DecryptedMessage_Unimplemented extends DecryptedMessage {
  const DecryptedMessage_Unimplemented() : super._();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DecryptedMessage_Unimplemented);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'DecryptedMessage.unimplemented()';
  }
}

// dart format on
