// SPDX-FileCopyrightText: 2019-Present, 2020, 2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';

abstract class MatrixLocalizations {
  const MatrixLocalizations();
  String get emptyChat;

  String get invitedUsersOnly;

  String get fromTheInvitation;

  String get fromJoining;

  String get visibleForAllParticipants;

  String get visibleForEveryone;

  String get guestsCanJoin;

  String get guestsAreForbidden;

  String get anyoneCanJoin;

  String get needPantalaimonWarning;

  String get channelCorruptedDecryptError;

  String get encryptionNotEnabled;

  String get unknownEncryptionAlgorithm;

  String get noPermission;

  String get you;

  String get roomHasBeenUpgraded;

  String get youAcceptedTheInvitation;

  String get youRejectedTheInvitation;

  String get youJoinedTheChat;

  String get unknownUser;

  String get cancelledSend;

  String get refreshingLastEvent;

  String youInvitedBy(String senderName);

  String invitedBy(String senderName);

  String youInvitedUser(String targetName);

  String youUnbannedUser(String targetName);

  String youBannedUser(String targetName);

  String youKicked(String targetName);

  String youKickedAndBanned(String targetName);

  String youHaveWithdrawnTheInvitationFor(String targetName);

  String groupWith(String displayname);

  String removedBy(Event redactedEvent);

  String sentASticker(String senderName);

  String redactedAnEvent(Event redactedEvent);

  String changedTheRoomAliases(String senderName);

  String changedTheRoomInvitationLink(String senderName);

  String createdTheChat(String senderName);

  String changedTheJoinRules(String senderName);

  String changedTheJoinRulesTo(String senderName, String localizedString);

  String acceptedTheInvitation(String targetName);

  String rejectedTheInvitation(String targetName);

  String hasWithdrawnTheInvitationFor(String senderName, String targetName);

  String joinedTheChat(String targetName);

  String kickedAndBanned(String senderName, String targetName);

  String kicked(String senderName, String targetName);

  String userLeftTheChat(String targetName);

  String bannedUser(String senderName, String targetName);

  String unbannedUser(String senderName, String targetName);

  String invitedUser(String senderName, String targetName);

  String changedTheProfileAvatar(String targetName);

  String changedTheDisplaynameTo(String targetName, String newDisplayname);

  String changedTheChatPermissions(String senderName);

  String changedTheChatNameTo(String senderName, String content);

  String changedTheChatDescriptionTo(String senderName, String content);

  String changedTheChatAvatar(String senderName);

  String changedTheGuestAccessRules(String senderName);

  String changedTheGuestAccessRulesTo(
    String senderName,
    String localizedString,
  );

  String changedTheHistoryVisibility(String senderName);

  String changedTheHistoryVisibilityTo(
    String senderName,
    String localizedString,
  );

  String activatedEndToEndEncryption(String senderName);

  String sentAPicture(String senderName);

  String sentAFile(String senderName);

  String sentAnAudio(String senderName);

  String voiceMessage(String senderName, Duration? duration);

  String sentAVideo(String senderName);

  String sentReaction(String senderName, String reactionKey);

  String sharedTheLocation(String senderName);

  String couldNotDecryptMessage(String errorText);

  String unknownEvent(String typeKey);

  String startedACall(String senderName);

  String endedTheCall(String senderName);

  String answeredTheCall(String senderName);

  String sentCallInformations(String senderName);

  String wasDirectChatDisplayName(String oldDisplayName);

  String hasKnocked(String targetName);

  String requestedKeyVerification(String senderName);

  String startedKeyVerification(String senderName);

  String acceptedKeyVerification(String senderName);

  String isReadyForKeyVerification(String senderName);

  String completedKeyVerification(String senderName);

  String canceledKeyVerification(String senderName);

  String startedAPoll(String senderName);

  String get pollHasBeenEnded;

  String usersHaveChangedTheirKeys(List<String> users);
}

extension HistoryVisibilityDisplayString on HistoryVisibility {
  String getLocalizedString(MatrixLocalizations i18n) {
    switch (this) {
      case HistoryVisibility.invited:
        return i18n.fromTheInvitation;
      case HistoryVisibility.joined:
        return i18n.fromJoining;
      case HistoryVisibility.shared:
        return i18n.visibleForAllParticipants;
      case HistoryVisibility.worldReadable:
        return i18n.visibleForEveryone;
    }
  }
}

extension GuestAccessDisplayString on GuestAccess {
  String getLocalizedString(MatrixLocalizations i18n) {
    switch (this) {
      case GuestAccess.canJoin:
        return i18n.guestsCanJoin;
      case GuestAccess.forbidden:
        return i18n.guestsAreForbidden;
    }
  }
}

extension JoinRulesDisplayString on JoinRules {
  String getLocalizedString(MatrixLocalizations i18n) {
    switch (this) {
      case JoinRules.public:
        return i18n.anyoneCanJoin;
      case JoinRules.invite:
        return i18n.invitedUsersOnly;
      default:
        return toString().replaceAll('JoinRules.', '');
    }
  }
}
