/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020, 2021 Famedly GmbH
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

import '../../encryption.dart';
import '../../famedlysdk.dart';
import '../event.dart';
import '../room.dart';
import 'matrix_localizations.dart';

abstract class EventLocalizations {
  static String _localizedBodyNormalMessage(
      Event event, MatrixLocalizations i18n) {
    switch (event.messageType) {
      case MessageTypes.Image:
        return i18n.sentAPicture(event.senderName);
      case MessageTypes.File:
        return i18n.sentAFile(event.senderName);
      case MessageTypes.Audio:
        return i18n.sentAnAudio(event.senderName);
      case MessageTypes.Video:
        return i18n.sentAVideo(event.senderName);
      case MessageTypes.Location:
        return i18n.sharedTheLocation(event.senderName);
      case MessageTypes.Sticker:
        return i18n.sentASticker(event.senderName);
      case MessageTypes.Emote:
        return '* ${event.body}';
      case MessageTypes.BadEncrypted:
        String errorText;
        switch (event.body) {
          case DecryptError.CHANNEL_CORRUPTED:
            errorText = i18n.channelCorruptedDecryptError + '.';
            break;
          case DecryptError.NOT_ENABLED:
            errorText = i18n.encryptionNotEnabled + '.';
            break;
          case DecryptError.UNKNOWN_ALGORITHM:
            errorText = i18n.unknownEncryptionAlgorithm + '.';
            break;
          case DecryptError.UNKNOWN_SESSION:
            errorText = i18n.noPermission + '.';
            break;
          default:
            errorText = event.body;
            break;
        }
        return i18n.couldNotDecryptMessage(errorText);
      case MessageTypes.Text:
      case MessageTypes.Notice:
      case MessageTypes.None:
      default:
        return event.body;
    }
  }

  // This map holds how to localize event types, and thus which event types exist.
  // If an event exists but it does not have a localized body, set its callback to null
  static final Map<String,
          String Function(Event event, MatrixLocalizations i18n)>
      localizationsMap = {
    EventTypes.Sticker: (event, i18n) => i18n.sentASticker(event.senderName),
    EventTypes.Redaction: (event, i18n) =>
        i18n.redactedAnEvent(event.senderName),
    EventTypes.RoomAliases: (event, i18n) =>
        i18n.changedTheRoomAliases(event.senderName),
    EventTypes.RoomCanonicalAlias: (event, i18n) =>
        i18n.changedTheRoomInvitationLink(event.senderName),
    EventTypes.RoomCreate: (event, i18n) =>
        i18n.createdTheChat(event.senderName),
    EventTypes.RoomTombstone: (event, i18n) => i18n.roomHasBeenUpgraded,
    EventTypes.RoomJoinRules: (event, i18n) {
      var joinRules = JoinRules.values.firstWhere(
          (r) =>
              r.toString().replaceAll('JoinRules.', '') ==
              event.content['join_rule'],
          orElse: () => null);
      if (joinRules == null) {
        return i18n.changedTheJoinRules(event.senderName);
      } else {
        return i18n.changedTheJoinRulesTo(
            event.senderName, joinRules.getLocalizedString(i18n));
      }
    },
    EventTypes.RoomMember: (event, i18n) {
      var text = 'Failed to parse member event';
      final targetName = event.stateKeyUser.calcDisplayname();
      // Has the membership changed?
      final newMembership = event.content['membership'] ?? '';
      final oldMembership = event.prevContent != null
          ? event.prevContent['membership'] ?? ''
          : '';
      if (newMembership != oldMembership) {
        if (oldMembership == 'invite' && newMembership == 'join') {
          text = i18n.acceptedTheInvitation(targetName);
        } else if (oldMembership == 'invite' && newMembership == 'leave') {
          if (event.stateKey == event.senderId) {
            text = i18n.rejectedTheInvitation(targetName);
          } else {
            text =
                i18n.hasWithdrawnTheInvitationFor(event.senderName, targetName);
          }
        } else if (oldMembership == 'leave' && newMembership == 'join') {
          text = i18n.joinedTheChat(targetName);
        } else if (oldMembership == 'join' && newMembership == 'ban') {
          text = i18n.kickedAndBanned(event.senderName, targetName);
        } else if (oldMembership == 'join' &&
            newMembership == 'leave' &&
            event.stateKey != event.senderId) {
          text = i18n.kicked(event.senderName, targetName);
        } else if (oldMembership == 'join' &&
            newMembership == 'leave' &&
            event.stateKey == event.senderId) {
          text = i18n.userLeftTheChat(targetName);
        } else if (oldMembership == 'invite' && newMembership == 'ban') {
          text = i18n.bannedUser(event.senderName, targetName);
        } else if (oldMembership == 'leave' && newMembership == 'ban') {
          text = i18n.bannedUser(event.senderName, targetName);
        } else if (oldMembership == 'ban' && newMembership == 'leave') {
          text = i18n.unbannedUser(event.senderName, targetName);
        } else if (newMembership == 'invite') {
          text = i18n.invitedUser(event.senderName, targetName);
        } else if (newMembership == 'join') {
          text = i18n.joinedTheChat(targetName);
        }
      } else if (newMembership == 'join') {
        final newAvatar = event.content['avatar_url'] ?? '';
        final oldAvatar = event.prevContent != null
            ? event.prevContent['avatar_url'] ?? ''
            : '';

        final newDisplayname = event.content['displayname'] ?? '';
        final oldDisplayname = event.prevContent != null
            ? event.prevContent['displayname'] ?? ''
            : '';

        // Has the user avatar changed?
        if (newAvatar != oldAvatar) {
          text = i18n.changedTheProfileAvatar(targetName);
        }
        // Has the user avatar changed?
        else if (newDisplayname != oldDisplayname) {
          text = i18n.changedTheDisplaynameTo(event.stateKey, newDisplayname);
        }
      }
      return text;
    },
    EventTypes.RoomPowerLevels: (event, i18n) =>
        i18n.changedTheChatPermissions(event.senderName),
    EventTypes.RoomName: (event, i18n) =>
        i18n.changedTheChatNameTo(event.senderName, event.content['name']),
    EventTypes.RoomTopic: (event, i18n) => i18n.changedTheChatDescriptionTo(
        event.senderName, event.content['topic']),
    EventTypes.RoomAvatar: (event, i18n) =>
        i18n.changedTheChatAvatar(event.senderName),
    EventTypes.GuestAccess: (event, i18n) {
      var guestAccess = GuestAccess.values.firstWhere(
          (r) =>
              r.toString().replaceAll('GuestAccess.', '') ==
              event.content['guest_access'],
          orElse: () => null);
      if (guestAccess == null) {
        return i18n.changedTheGuestAccessRules(event.senderName);
      } else {
        return i18n.changedTheGuestAccessRulesTo(
            event.senderName, guestAccess.getLocalizedString(i18n));
      }
    },
    EventTypes.HistoryVisibility: (event, i18n) {
      var historyVisibility = HistoryVisibility.values.firstWhere(
          (r) =>
              r.toString().replaceAll('HistoryVisibility.', '') ==
              event.content['history_visibility'],
          orElse: () => null);
      if (historyVisibility == null) {
        return i18n.changedTheHistoryVisibility(event.senderName);
      } else {
        return i18n.changedTheHistoryVisibilityTo(
            event.senderName, historyVisibility.getLocalizedString(i18n));
      }
    },
    EventTypes.Encryption: (event, i18n) {
      var localizedBody = i18n.activatedEndToEndEncryption(event.senderName);
      if (!event.room.client.encryptionEnabled) {
        localizedBody += '. ' + i18n.needPantalaimonWarning;
      }
      return localizedBody;
    },
    EventTypes.CallAnswer: (event, i18n) =>
        i18n.answeredTheCall(event.senderName),
    EventTypes.CallHangup: (event, i18n) => i18n.endedTheCall(event.senderName),
    EventTypes.CallInvite: (event, i18n) => i18n.startedACall(event.senderName),
    EventTypes.CallCandidates: (event, i18n) =>
        i18n.sentCallInformations(event.senderName),
    EventTypes.Encrypted: (event, i18n) =>
        _localizedBodyNormalMessage(event, i18n),
    EventTypes.Message: (event, i18n) =>
        _localizedBodyNormalMessage(event, i18n),
    EventTypes.Reaction: null,
  };
}
