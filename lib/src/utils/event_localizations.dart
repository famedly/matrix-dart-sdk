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

import 'package:collection/collection.dart';

import '../../encryption.dart';
import '../../matrix.dart';
import '../event.dart';
import '../room.dart';
import 'matrix_localizations.dart';

abstract class EventLocalizations {
  // As we need to create the localized body off of a different set of parameters, we
  // might create it with `event.plaintextBody`, maybe with `event.body`, maybe with the
  // reply fallback stripped, and maybe with the new body in `event.content['m.new_content']`.
  // Thus, it seems easier to offload that logic into `Event.getLocalizedBody()` and pass the
  // `body` variable around here.
  static String _localizedBodyNormalMessage(
      Event event, MatrixLocalizations i18n, String body) {
    switch (event.messageType) {
      case MessageTypes.Image:
        return i18n.sentAPicture(event.sender.calcDisplayname());
      case MessageTypes.File:
        return i18n.sentAFile(event.sender.calcDisplayname());
      case MessageTypes.Audio:
        return i18n.sentAnAudio(event.sender.calcDisplayname());
      case MessageTypes.Video:
        return i18n.sentAVideo(event.sender.calcDisplayname());
      case MessageTypes.Location:
        return i18n.sharedTheLocation(event.sender.calcDisplayname());
      case MessageTypes.Sticker:
        return i18n.sentASticker(event.sender.calcDisplayname());
      case MessageTypes.Emote:
        return '* $body';
      case MessageTypes.BadEncrypted:
        String errorText;
        switch (event.body) {
          case DecryptException.channelCorrupted:
            errorText = i18n.channelCorruptedDecryptError + '.';
            break;
          case DecryptException.notEnabled:
            errorText = i18n.encryptionNotEnabled + '.';
            break;
          case DecryptException.unknownAlgorithm:
            errorText = i18n.unknownEncryptionAlgorithm + '.';
            break;
          case DecryptException.unknownSession:
            errorText = i18n.noPermission + '.';
            break;
          default:
            errorText = body;
            break;
        }
        return i18n.couldNotDecryptMessage(errorText);
      case MessageTypes.Text:
      case MessageTypes.Notice:
      case MessageTypes.None:
      default:
        return body;
    }
  }

  // This map holds how to localize event types, and thus which event types exist.
  // If an event exists but it does not have a localized body, set its callback to null
  static final Map<String,
          String Function(Event event, MatrixLocalizations i18n, String body)?>
      localizationsMap = {
    EventTypes.Sticker: (event, i18n, body) =>
        i18n.sentASticker(event.sender.calcDisplayname()),
    EventTypes.Redaction: (event, i18n, body) =>
        i18n.redactedAnEvent(event.sender.calcDisplayname()),
    EventTypes.RoomAliases: (event, i18n, body) =>
        i18n.changedTheRoomAliases(event.sender.calcDisplayname()),
    EventTypes.RoomCanonicalAlias: (event, i18n, body) =>
        i18n.changedTheRoomInvitationLink(event.sender.calcDisplayname()),
    EventTypes.RoomCreate: (event, i18n, body) =>
        i18n.createdTheChat(event.sender.calcDisplayname()),
    EventTypes.RoomTombstone: (event, i18n, body) => i18n.roomHasBeenUpgraded,
    EventTypes.RoomJoinRules: (event, i18n, body) {
      final joinRules = JoinRules.values.firstWhereOrNull((r) =>
          r.toString().replaceAll('JoinRules.', '') ==
          event.content['join_rule']);
      if (joinRules == null) {
        return i18n.changedTheJoinRules(event.sender.calcDisplayname());
      } else {
        return i18n.changedTheJoinRulesTo(
            event.sender.calcDisplayname(), joinRules.getLocalizedString(i18n));
      }
    },
    EventTypes.RoomMember: (event, i18n, body) {
      var text = 'Failed to parse member event';
      final targetName = event.stateKeyUser?.calcDisplayname() ?? '';
      // Has the membership changed?
      final newMembership = event.content['membership'] ?? '';
      final oldMembership = event.prevContent?['membership'] ?? '';

      if (newMembership != oldMembership) {
        if (oldMembership == 'invite' && newMembership == 'join') {
          text = i18n.acceptedTheInvitation(targetName);
        } else if (oldMembership == 'invite' && newMembership == 'leave') {
          if (event.stateKey == event.senderId) {
            text = i18n.rejectedTheInvitation(targetName);
          } else {
            text = i18n.hasWithdrawnTheInvitationFor(
                event.sender.calcDisplayname(), targetName);
          }
        } else if (oldMembership == 'leave' && newMembership == 'join') {
          text = i18n.joinedTheChat(targetName);
        } else if (oldMembership == 'join' && newMembership == 'ban') {
          text =
              i18n.kickedAndBanned(event.sender.calcDisplayname(), targetName);
        } else if (oldMembership == 'join' &&
            newMembership == 'leave' &&
            event.stateKey != event.senderId) {
          text = i18n.kicked(event.sender.calcDisplayname(), targetName);
        } else if (oldMembership == 'join' &&
            newMembership == 'leave' &&
            event.stateKey == event.senderId) {
          text = i18n.userLeftTheChat(targetName);
        } else if (oldMembership == 'invite' && newMembership == 'ban') {
          text = i18n.bannedUser(event.sender.calcDisplayname(), targetName);
        } else if (oldMembership == 'leave' && newMembership == 'ban') {
          text = i18n.bannedUser(event.sender.calcDisplayname(), targetName);
        } else if (oldMembership == 'ban' && newMembership == 'leave') {
          text = i18n.unbannedUser(event.sender.calcDisplayname(), targetName);
        } else if (newMembership == 'invite') {
          text = i18n.invitedUser(event.sender.calcDisplayname(), targetName);
        } else if (newMembership == 'join') {
          text = i18n.joinedTheChat(targetName);
        }
      } else if (newMembership == 'join') {
        final newAvatar = event.content['avatar_url'] ?? '';
        final oldAvatar = event.prevContent?['avatar_url'] ?? '';

        final newDisplayname = event.content['displayname'] ?? '';
        final oldDisplayname = event.prevContent?['displayname'] ?? '';
        final stateKey = event.stateKey;

        // Has the user avatar changed?
        if (newAvatar != oldAvatar) {
          text = i18n.changedTheProfileAvatar(targetName);
        }
        // Has the user displayname changed?
        else if (newDisplayname != oldDisplayname && stateKey != null) {
          text = i18n.changedTheDisplaynameTo(stateKey, newDisplayname);
        }
      }
      return text;
    },
    EventTypes.RoomPowerLevels: (event, i18n, body) =>
        i18n.changedTheChatPermissions(event.sender.calcDisplayname()),
    EventTypes.RoomName: (event, i18n, body) => i18n.changedTheChatNameTo(
        event.sender.calcDisplayname(), event.content['name']),
    EventTypes.RoomTopic: (event, i18n, body) =>
        i18n.changedTheChatDescriptionTo(
            event.sender.calcDisplayname(), event.content['topic']),
    EventTypes.RoomAvatar: (event, i18n, body) =>
        i18n.changedTheChatAvatar(event.sender.calcDisplayname()),
    EventTypes.GuestAccess: (event, i18n, body) {
      final guestAccess = GuestAccess.values.firstWhereOrNull((r) =>
          r.toString().replaceAll('GuestAccess.', '') ==
          event.content['guest_access']);
      if (guestAccess == null) {
        return i18n.changedTheGuestAccessRules(event.sender.calcDisplayname());
      } else {
        return i18n.changedTheGuestAccessRulesTo(event.sender.calcDisplayname(),
            guestAccess.getLocalizedString(i18n));
      }
    },
    EventTypes.HistoryVisibility: (event, i18n, body) {
      final historyVisibility = HistoryVisibility.values.firstWhereOrNull((r) =>
          r.toString().replaceAll('HistoryVisibility.', '') ==
          event.content['history_visibility']);
      if (historyVisibility == null) {
        return i18n.changedTheHistoryVisibility(event.sender.calcDisplayname());
      } else {
        return i18n.changedTheHistoryVisibilityTo(
            event.sender.calcDisplayname(),
            historyVisibility.getLocalizedString(i18n));
      }
    },
    EventTypes.Encryption: (event, i18n, body) {
      var localizedBody =
          i18n.activatedEndToEndEncryption(event.sender.calcDisplayname());
      if (event.room?.client.encryptionEnabled == false) {
        localizedBody += '. ' + i18n.needPantalaimonWarning;
      }
      return localizedBody;
    },
    EventTypes.CallAnswer: (event, i18n, body) =>
        i18n.answeredTheCall(event.sender.calcDisplayname()),
    EventTypes.CallHangup: (event, i18n, body) =>
        i18n.endedTheCall(event.sender.calcDisplayname()),
    EventTypes.CallInvite: (event, i18n, body) =>
        i18n.startedACall(event.sender.calcDisplayname()),
    EventTypes.CallCandidates: (event, i18n, body) =>
        i18n.sentCallInformations(event.sender.calcDisplayname()),
    EventTypes.Encrypted: (event, i18n, body) =>
        _localizedBodyNormalMessage(event, i18n, body),
    EventTypes.Message: (event, i18n, body) =>
        _localizedBodyNormalMessage(event, i18n, body),
    EventTypes.Reaction: null,
  };
}
