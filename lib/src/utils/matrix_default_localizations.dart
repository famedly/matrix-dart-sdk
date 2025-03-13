/*
 *   Famedly Matrix SDK
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

import 'package:matrix/matrix.dart';

class MatrixDefaultLocalizations extends MatrixLocalizations {
  const MatrixDefaultLocalizations();
  @override
  String acceptedTheInvitation(String targetName) =>
      '$targetName accepted the invitation';

  @override
  String activatedEndToEndEncryption(String senderName) =>
      '$senderName activated end to end encryption';

  @override
  String get anyoneCanJoin => 'Anyone can join';

  @override
  String bannedUser(String senderName, String targetName) =>
      '$senderName banned $targetName';

  @override
  String changedTheChatAvatar(String senderName) =>
      '$senderName changed the chat avatar';

  @override
  String changedTheChatDescriptionTo(String senderName, String content) =>
      '$senderName changed the chat description to $content';

  @override
  String changedTheChatNameTo(String senderName, String content) =>
      '$senderName changed the chat name to $content';

  @override
  String changedTheChatPermissions(String senderName) =>
      '$senderName changed the chat permissions';

  @override
  String changedTheDisplaynameTo(String targetName, String newDisplayname) =>
      '$targetName changed the displayname to $newDisplayname';

  @override
  String changedTheGuestAccessRules(String senderName) =>
      '$senderName changed the guest access rules';

  @override
  String changedTheGuestAccessRulesTo(
    String senderName,
    String localizedString,
  ) =>
      '$senderName changed the guest access rules to $localizedString';

  @override
  String changedTheHistoryVisibility(String senderName) =>
      '$senderName changed the history visibility';

  @override
  String changedTheHistoryVisibilityTo(
    String senderName,
    String localizedString,
  ) =>
      '$senderName changed the history visibility to $localizedString';

  @override
  String changedTheJoinRules(String senderName) =>
      '$senderName changed the join rules';

  @override
  String changedTheJoinRulesTo(String senderName, String localizedString) =>
      '$senderName changed the join rules to $localizedString';

  @override
  String changedTheProfileAvatar(String targetName) =>
      '$targetName changed the profile avatar';

  @override
  String changedTheRoomAliases(String senderName) =>
      '$senderName changed the room aliases';

  @override
  String changedTheRoomInvitationLink(String senderName) =>
      '$senderName changed the room invitation link';

  @override
  String get channelCorruptedDecryptError =>
      'The secure channel has been corrupted';

  @override
  String couldNotDecryptMessage(String errorText) =>
      'Could not decrypt message: $errorText';

  @override
  String createdTheChat(String senderName) => '$senderName created the chat';

  @override
  String get emptyChat => 'Empty chat';

  @override
  String get encryptionNotEnabled => 'Encryption not enabled';

  @override
  String get fromJoining => 'From joining';

  @override
  String get fromTheInvitation => 'From the invitation';

  @override
  String groupWith(String displayname) => 'Group with $displayname';

  @override
  String get guestsAreForbidden => 'Guests are forbidden';

  @override
  String get guestsCanJoin => 'Guests can join';

  @override
  String get cancelledSend => 'Cancelled sending message';

  @override
  String hasWithdrawnTheInvitationFor(String senderName, String targetName) =>
      '$senderName has withdrawn the invitation for $targetName';

  @override
  String invitedUser(String senderName, String targetName) =>
      '$senderName has invited $targetName';

  @override
  String get invitedUsersOnly => 'Invited users only';

  @override
  String joinedTheChat(String targetName) => '$targetName joined the chat';

  @override
  String kicked(String senderName, String targetName) =>
      '$senderName kicked $targetName';

  @override
  String kickedAndBanned(String senderName, String targetName) =>
      '$senderName banned $targetName';

  @override
  String get needPantalaimonWarning => 'Need pantalaimon';

  @override
  String get noPermission => 'No permission';

  @override
  String redactedAnEvent(Event redactedEvent) =>
      '${redactedEvent.senderFromMemoryOrFallback.calcDisplayname()} redacted an event';

  @override
  String rejectedTheInvitation(String targetName) =>
      '$targetName rejected the invitation';

  @override
  String removedBy(Event redactedEvent) =>
      'Removed by ${redactedEvent.senderFromMemoryOrFallback.calcDisplayname()}';

  @override
  String get roomHasBeenUpgraded => 'Room has been upgraded';

  @override
  String sentAFile(String senderName) => '$senderName sent a file';

  @override
  String sentAPicture(String senderName) => '$senderName sent a picture';

  @override
  String sentASticker(String senderName) => '$senderName sent a sticker';

  @override
  String sentAVideo(String senderName) => '$senderName sent a video';

  @override
  String sentAnAudio(String senderName) => '$senderName sent an audio';

  @override
  String sharedTheLocation(String senderName) =>
      '$senderName shared the location';

  @override
  String unbannedUser(String senderName, String targetName) =>
      '$senderName unbanned $targetName';

  @override
  String get unknownEncryptionAlgorithm => 'Unknown encryption algorithm';

  @override
  String unknownEvent(String typeKey) => 'Unknown event $typeKey';

  @override
  String userLeftTheChat(String targetName) => '$targetName left the chat';

  @override
  String get visibleForAllParticipants => 'Visible for all participants';

  @override
  String get visibleForEveryone => 'Visible for everyone';

  @override
  String get you => 'You';

  @override
  String answeredTheCall(String senderName) {
    return 'answeredTheCall';
  }

  @override
  String endedTheCall(String senderName) {
    return 'endedTheCall';
  }

  @override
  String sentCallInformations(String senderName) {
    return 'sentCallInformations';
  }

  @override
  String startedACall(String senderName) {
    return 'startedACall';
  }

  @override
  String sentReaction(String senderName, String reactionKey) {
    return '$senderName reacted with $reactionKey';
  }

  @override
  String get youAcceptedTheInvitation => 'You accepted the invitation';

  @override
  String youBannedUser(String targetName) => 'You have banned $targetName';

  @override
  String youHaveWithdrawnTheInvitationFor(String targetName) =>
      'You have withdrawn the invitation for $targetName';

  @override
  String youInvitedBy(String senderName) =>
      'You have been invited by $senderName';

  @override
  String invitedBy(String senderName) => 'Invited by $senderName';

  @override
  String youInvitedUser(String targetName) => 'You invited $targetName';

  @override
  String get youJoinedTheChat => 'You joined the chat';

  @override
  String youKicked(String targetName) => 'You kicked $targetName';

  @override
  String youKickedAndBanned(String targetName) =>
      'You kicked and banned $targetName';

  @override
  String get youRejectedTheInvitation => 'You have rejected the invitation';

  @override
  String youUnbannedUser(String targetName) => 'You unbanned $targetName';

  @override
  String wasDirectChatDisplayName(String oldDisplayName) =>
      'Empty chat (was $oldDisplayName)';

  @override
  String get unknownUser => 'Unknown user';

  @override
  String hasKnocked(String targetName) => '$targetName has knocked';

  @override
  String acceptedKeyVerification(String senderName) =>
      '$senderName accepted key verification request';

  @override
  String canceledKeyVerification(String senderName) =>
      '$senderName canceled key verification';

  @override
  String completedKeyVerification(String senderName) =>
      '$senderName completed key verification';

  @override
  String isReadyForKeyVerification(String senderName) =>
      '$senderName is ready for key verification';

  @override
  String requestedKeyVerification(String senderName) =>
      '$senderName requested key verification';

  @override
  String startedKeyVerification(String senderName) =>
      '$senderName started key verification';

  @override
  String userCanNowReadAlong(List<String> userIds, List<String>? devices) =>
      '${userIds.join(', ')} can now read along${devices == null ? '' : ' on ${devices.length} new device(s)'}';
}
