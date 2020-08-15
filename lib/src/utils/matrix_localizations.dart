import '../room.dart';

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

  String groupWith(String displayname);

  String removedBy(String calcDisplayname);

  String sentASticker(String senderName);

  String redactedAnEvent(String senderName);

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
      String senderName, String localizedString);

  String changedTheHistoryVisibility(String senderName);

  String changedTheHistoryVisibilityTo(
      String senderName, String localizedString);

  String activatedEndToEndEncryption(String senderName);

  String sentAPicture(String senderName);

  String sentAFile(String senderName);

  String sentAnAudio(String senderName);

  String sentAVideo(String senderName);

  String sharedTheLocation(String senderName);

  String couldNotDecryptMessage(String errorText);

  String unknownEvent(String typeKey);

  String startedACall(String senderName);

  String endedTheCall(String senderName);

  String answeredTheCall(String senderName);

  String sentCallInformations(String senderName);
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
      case HistoryVisibility.world_readable:
        return i18n.visibleForEveryone;
    }
    return null;
  }
}

extension GuestAccessDisplayString on GuestAccess {
  String getLocalizedString(MatrixLocalizations i18n) {
    switch (this) {
      case GuestAccess.can_join:
        return i18n.guestsCanJoin;
      case GuestAccess.forbidden:
        return i18n.guestsAreForbidden;
    }
    return null;
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
