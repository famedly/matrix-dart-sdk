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

import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/msc_extensions/msc_3381_polls/models/poll_event_content.dart';

abstract class EventLocalizations {
  // As we need to create the localized body off of a different set of parameters, we
  // might create it with `event.plaintextBody`, maybe with `event.body`, maybe with the
  // reply fallback stripped, and maybe with the new body in `event.content['m.new_content']`.
  // Thus, it seems easier to offload that logic into `Event.getLocalizedBody()` and pass the
  // `body` variable around here.
  static String _localizedBodyNormalMessage(
    Event event,
    MatrixLocalizations i18n,
    String body,
  ) {
    switch (event.messageType) {
      case MessageTypes.Image:
        return i18n.sentAPicture(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        );
      case MessageTypes.File:
        return i18n.sentAFile(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        );
      case MessageTypes.Audio:
        return i18n.sentAnAudio(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        );
      case MessageTypes.Video:
        return i18n.sentAVideo(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        );
      case MessageTypes.Location:
        return i18n.sharedTheLocation(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        );
      case MessageTypes.Sticker:
        return i18n.sentASticker(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        );
      case MessageTypes.Emote:
        return '* $body';
      case EventTypes.KeyVerificationRequest:
        return i18n.requestedKeyVerification(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        );
      case EventTypes.KeyVerificationCancel:
        return i18n.canceledKeyVerification(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        );
      case EventTypes.KeyVerificationDone:
        return i18n.completedKeyVerification(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        );
      case EventTypes.KeyVerificationReady:
        return i18n.isReadyForKeyVerification(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        );
      case EventTypes.KeyVerificationAccept:
        return i18n.acceptedKeyVerification(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        );
      case EventTypes.KeyVerificationStart:
        return i18n.startedKeyVerification(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        );
      case MessageTypes.BadEncrypted:
        String errorText;
        switch (event.body) {
          case DecryptException.channelCorrupted:
            errorText = '${i18n.channelCorruptedDecryptError}.';
            break;
          case DecryptException.notEnabled:
            errorText = '${i18n.encryptionNotEnabled}.';
            break;
          case DecryptException.unknownAlgorithm:
            errorText = '${i18n.unknownEncryptionAlgorithm}.';
            break;
          case DecryptException.unknownSession:
            errorText = '${i18n.noPermission}.';
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
    EventTypes.Sticker: (event, i18n, body) => i18n.sentASticker(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        ),
    EventTypes.Redaction: (event, i18n, body) => i18n.redactedAnEvent(event),
    EventTypes.RoomAliases: (event, i18n, body) => i18n.changedTheRoomAliases(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        ),
    EventTypes.RoomCanonicalAlias: (event, i18n, body) =>
        i18n.changedTheRoomInvitationLink(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        ),
    EventTypes.RoomCreate: (event, i18n, body) => i18n.createdTheChat(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        ),
    EventTypes.RoomTombstone: (event, i18n, body) => i18n.roomHasBeenUpgraded,
    EventTypes.RoomJoinRules: (event, i18n, body) {
      final joinRules = JoinRules.values.firstWhereOrNull(
        (r) =>
            r.toString().replaceAll('JoinRules.', '') ==
            event.content['join_rule'],
      );
      if (joinRules == null) {
        return i18n.changedTheJoinRules(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        );
      } else {
        return i18n.changedTheJoinRulesTo(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
          joinRules.getLocalizedString(i18n),
        );
      }
    },
    EventTypes.RoomMember: (event, i18n, body) {
      final targetName = event.stateKeyUser?.calcDisplayname(i18n: i18n) ?? '';
      final senderName =
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n);
      final userIsTarget = event.stateKey == event.room.client.userID;
      final userIsSender = event.senderId == event.room.client.userID;

      switch (event.roomMemberChangeType) {
        case RoomMemberChangeType.avatar:
          return i18n.changedTheProfileAvatar(targetName);
        case RoomMemberChangeType.displayname:
          final newDisplayname =
              event.content.tryGet<String>('displayname') ?? '';
          final oldDisplayname =
              event.prevContent?.tryGet<String>('displayname') ?? '';
          return i18n.changedTheDisplaynameTo(oldDisplayname, newDisplayname);
        case RoomMemberChangeType.join:
          return userIsTarget
              ? i18n.youJoinedTheChat
              : i18n.joinedTheChat(targetName);
        case RoomMemberChangeType.acceptInvite:
          return userIsTarget
              ? i18n.youAcceptedTheInvitation
              : i18n.acceptedTheInvitation(targetName);
        case RoomMemberChangeType.rejectInvite:
          return userIsTarget
              ? i18n.youRejectedTheInvitation
              : i18n.rejectedTheInvitation(targetName);
        case RoomMemberChangeType.withdrawInvitation:
          return userIsSender
              ? i18n.youHaveWithdrawnTheInvitationFor(targetName)
              : i18n.hasWithdrawnTheInvitationFor(senderName, targetName);
        case RoomMemberChangeType.leave:
          return i18n.userLeftTheChat(targetName);
        case RoomMemberChangeType.kick:
          return userIsSender
              ? i18n.youKicked(targetName)
              : i18n.kicked(senderName, targetName);
        case RoomMemberChangeType.invite:
          return userIsSender
              ? i18n.youInvitedUser(targetName)
              : userIsTarget
                  ? i18n.youInvitedBy(senderName)
                  : i18n.invitedUser(senderName, targetName);
        case RoomMemberChangeType.ban:
          return userIsSender
              ? i18n.youBannedUser(targetName)
              : i18n.bannedUser(senderName, targetName);
        case RoomMemberChangeType.unban:
          return userIsSender
              ? i18n.youUnbannedUser(targetName)
              : i18n.unbannedUser(senderName, targetName);
        case RoomMemberChangeType.knock:
          return i18n.hasKnocked(targetName);
        case RoomMemberChangeType.other:
          return userIsTarget
              ? i18n.youJoinedTheChat
              : i18n.joinedTheChat(targetName);
      }
    },
    EventTypes.RoomPowerLevels: (event, i18n, body) =>
        i18n.changedTheChatPermissions(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        ),
    EventTypes.RoomName: (event, i18n, body) => i18n.changedTheChatNameTo(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
          event.content.tryGet<String>('name') ?? '',
        ),
    EventTypes.RoomTopic: (event, i18n, body) =>
        i18n.changedTheChatDescriptionTo(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
          event.content.tryGet<String>('topic') ?? '',
        ),
    EventTypes.RoomAvatar: (event, i18n, body) => i18n.changedTheChatAvatar(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        ),
    EventTypes.GuestAccess: (event, i18n, body) {
      final guestAccess = GuestAccess.values.firstWhereOrNull(
        (r) =>
            r.toString().replaceAll('GuestAccess.', '') ==
            event.content['guest_access'],
      );
      if (guestAccess == null) {
        return i18n.changedTheGuestAccessRules(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        );
      } else {
        return i18n.changedTheGuestAccessRulesTo(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
          guestAccess.getLocalizedString(i18n),
        );
      }
    },
    EventTypes.HistoryVisibility: (event, i18n, body) {
      final historyVisibility = HistoryVisibility.values.firstWhereOrNull(
        (r) =>
            r.toString().replaceAll('HistoryVisibility.', '') ==
            event.content['history_visibility'],
      );
      if (historyVisibility == null) {
        return i18n.changedTheHistoryVisibility(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        );
      } else {
        return i18n.changedTheHistoryVisibilityTo(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
          historyVisibility.getLocalizedString(i18n),
        );
      }
    },
    EventTypes.Encryption: (event, i18n, body) {
      var localizedBody = i18n.activatedEndToEndEncryption(
        event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
      );
      if (event.room.client.encryptionEnabled == false) {
        localizedBody += '. ${i18n.needPantalaimonWarning}';
      }
      return localizedBody;
    },
    EventTypes.CallAnswer: (event, i18n, body) => i18n.answeredTheCall(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        ),
    EventTypes.CallHangup: (event, i18n, body) => i18n.endedTheCall(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        ),
    EventTypes.CallInvite: (event, i18n, body) => i18n.startedACall(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        ),
    EventTypes.CallCandidates: (event, i18n, body) => i18n.sentCallInformations(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        ),
    EventTypes.Encrypted: (event, i18n, body) =>
        _localizedBodyNormalMessage(event, i18n, body),
    EventTypes.Message: (event, i18n, body) =>
        _localizedBodyNormalMessage(event, i18n, body),
    EventTypes.Reaction: (event, i18n, body) => i18n.sentReaction(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
          event.content
                  .tryGetMap<String, Object?>('m.relates_to')
                  ?.tryGet<String>('key') ??
              body,
        ),
    PollEventContent.startType: (event, i18n, body) => i18n.startedAPoll(
          event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
        ),
  };
}
