/*
 *   Ansible inventory script used at Famedly GmbH for managing many hosts
 *   Copyright (C) 2019, 2020 Famedly GmbH
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

import 'package:famedlysdk/famedlysdk.dart';

class FakeMatrixLocalizations extends MatrixLocalizations {
  @override
  String acceptedTheInvitation(String targetName) {
    // TODO: implement acceptedTheInvitation
    return null;
  }

  @override
  String activatedEndToEndEncryption(String senderName) {
    // TODO: implement activatedEndToEndEncryption
    return '$senderName activatedEndToEndEncryption';
  }

  @override
  // TODO: implement anyoneCanJoin
  String get anyoneCanJoin => null;

  @override
  String bannedUser(String senderName, String targetName) {
    // TODO: implement bannedUser
    return null;
  }

  @override
  String changedTheChatAvatar(String senderName) {
    // TODO: implement changedTheChatAvatar
    return null;
  }

  @override
  String changedTheChatDescriptionTo(String senderName, String content) {
    // TODO: implement changedTheChatDescriptionTo
    return null;
  }

  @override
  String changedTheChatNameTo(String senderName, String content) {
    // TODO: implement changedTheChatNameTo
    return null;
  }

  @override
  String changedTheChatPermissions(String senderName) {
    // TODO: implement changedTheChatPermissions
    return null;
  }

  @override
  String changedTheDisplaynameTo(String targetName, String newDisplayname) {
    // TODO: implement changedTheDisplaynameTo
    return null;
  }

  @override
  String changedTheGuestAccessRules(String senderName) {
    // TODO: implement changedTheGuestAccessRules
    return null;
  }

  @override
  String changedTheGuestAccessRulesTo(
      String senderName, String localizedString) {
    // TODO: implement changedTheGuestAccessRulesTo
    return null;
  }

  @override
  String changedTheHistoryVisibility(String senderName) {
    // TODO: implement changedTheHistoryVisibility
    return null;
  }

  @override
  String changedTheHistoryVisibilityTo(
      String senderName, String localizedString) {
    // TODO: implement changedTheHistoryVisibilityTo
    return null;
  }

  @override
  String changedTheJoinRules(String senderName) {
    // TODO: implement changedTheJoinRules
    return null;
  }

  @override
  String changedTheJoinRulesTo(String senderName, String localizedString) {
    // TODO: implement changedTheJoinRulesTo
    return null;
  }

  @override
  String changedTheProfileAvatar(String targetName) {
    // TODO: implement changedTheProfileAvatar
    return null;
  }

  @override
  String changedTheRoomAliases(String senderName) {
    // TODO: implement changedTheRoomAliases
    return null;
  }

  @override
  String changedTheRoomInvitationLink(String senderName) {
    // TODO: implement changedTheRoomInvitationLink
    return null;
  }

  @override
  // TODO: implement channelCorruptedDecryptError
  String get channelCorruptedDecryptError => null;

  @override
  String couldNotDecryptMessage(String errorText) {
    // TODO: implement couldNotDecryptMessage
    return null;
  }

  @override
  String createdTheChat(String senderName) {
    // TODO: implement createdTheChat
    return null;
  }

  @override
  // TODO: implement emptyChat
  String get emptyChat => null;

  @override
  // TODO: implement encryptionNotEnabled
  String get encryptionNotEnabled => null;

  @override
  // TODO: implement fromJoining
  String get fromJoining => null;

  @override
  // TODO: implement fromTheInvitation
  String get fromTheInvitation => null;

  @override
  String groupWith(String displayname) {
    // TODO: implement groupWith
    return null;
  }

  @override
  // TODO: implement guestsAreForbidden
  String get guestsAreForbidden => null;

  @override
  // TODO: implement guestsCanJoin
  String get guestsCanJoin => null;

  @override
  String hasWithdrawnTheInvitationFor(String senderName, String targetName) {
    // TODO: implement hasWithdrawnTheInvitationFor
    return null;
  }

  @override
  String invitedUser(String senderName, String targetName) {
    // TODO: implement invitedUser
    return null;
  }

  @override
  // TODO: implement invitedUsersOnly
  String get invitedUsersOnly => null;

  @override
  String joinedTheChat(String targetName) {
    // TODO: implement joinedTheChat
    return null;
  }

  @override
  String kicked(String senderName, String targetName) {
    // TODO: implement kicked
    return null;
  }

  @override
  String kickedAndBanned(String senderName, String targetName) {
    // TODO: implement kickedAndBanned
    return null;
  }

  @override
  // TODO: implement needPantalaimonWarning
  String get needPantalaimonWarning => 'needPantalaimonWarning';

  @override
  // TODO: implement noPermission
  String get noPermission => 'noPermission';

  @override
  String redactedAnEvent(String senderName) {
    // TODO: implement redactedAnEvent
    return null;
  }

  @override
  String rejectedTheInvitation(String targetName) {
    // TODO: implement rejectedTheInvitation
    return null;
  }

  @override
  String removedBy(String calcDisplayname) {
    // TODO: implement removedBy
    return null;
  }

  @override
  // TODO: implement roomHasBeenUpgraded
  String get roomHasBeenUpgraded => null;

  @override
  String sentAFile(String senderName) {
    // TODO: implement sentAFile
    return null;
  }

  @override
  String sentAPicture(String senderName) {
    // TODO: implement sentAPicture
    return null;
  }

  @override
  String sentASticker(String senderName) {
    // TODO: implement sentASticker
    return null;
  }

  @override
  String sentAVideo(String senderName) {
    // TODO: implement sentAVideo
    return null;
  }

  @override
  String sentAnAudio(String senderName) {
    // TODO: implement sentAnAudio
    return null;
  }

  @override
  String sharedTheLocation(String senderName) {
    // TODO: implement sharedTheLocation
    return null;
  }

  @override
  String unbannedUser(String senderName, String targetName) {
    // TODO: implement unbannedUser
    return null;
  }

  @override
  // TODO: implement unknownEncryptionAlgorithm
  String get unknownEncryptionAlgorithm => null;

  @override
  String unknownEvent(String typeKey) {
    // TODO: implement unknownEvent
    return null;
  }

  @override
  String userLeftTheChat(String targetName) {
    // TODO: implement userLeftTheChat
    return null;
  }

  @override
  // TODO: implement visibleForAllParticipants
  String get visibleForAllParticipants => null;

  @override
  // TODO: implement visibleForEveryone
  String get visibleForEveryone => null;

  @override
  // TODO: implement you
  String get you => null;

  @override
  String answeredTheCall(String senderName) {
    // TODO: implement answeredTheCall
    return null;
  }

  @override
  String endedTheCall(String senderName) {
    // TODO: implement endedTheCall
    return null;
  }

  @override
  String sentCallInformations(String senderName) {
    // TODO: implement sentCallInformations
    return null;
  }

  @override
  String startedACall(String senderName) {
    // TODO: implement startedACall
    return null;
  }
}
