/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020, 2021 Famedly GmbH
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

  String userCanNowReadAlong(List<String> userIds, List<String>? devices);

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
