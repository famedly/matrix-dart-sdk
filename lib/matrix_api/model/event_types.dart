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

abstract class EventTypes {
  static const String Message = 'm.room.message';
  static const String Sticker = 'm.sticker';
  static const String Reaction = 'm.reaction';
  static const String Redaction = 'm.room.redaction';
  static const String RoomAliases = 'm.room.aliases';
  static const String RoomCanonicalAlias = 'm.room.canonical_alias';
  static const String RoomCreate = 'm.room.create';
  static const String RoomJoinRules = 'm.room.join_rules';
  static const String RoomMember = 'm.room.member';
  static const String RoomPowerLevels = 'm.room.power_levels';
  static const String RoomName = 'm.room.name';
  static const String RoomPinnedEvents = 'm.room.pinned_events';
  static const String RoomTopic = 'm.room.topic';
  static const String RoomAvatar = 'm.room.avatar';
  static const String RoomTombstone = 'm.room.tombsone';
  static const String GuestAccess = 'm.room.guest_access';
  static const String HistoryVisibility = 'm.room.history_visibility';
  static const String Encryption = 'm.room.encryption';
  static const String Encrypted = 'm.room.encrypted';
  static const String CallInvite = 'm.room.call.invite';
  static const String CallAnswer = 'm.room.call.answer';
  static const String CallCandidates = 'm.room.call.candidates';
  static const String CallHangup = 'm.room.call.hangup';
  static const String Unknown = 'm.unknown';
}
