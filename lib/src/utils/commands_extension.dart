/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2021 Famedly GmbH
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

import 'dart:async';

import '../../matrix.dart';

extension CommandsClientExtension on Client {
  /// Add a command to the command handler. `command` is its name, and `callback` is the
  /// callback to invoke
  void addCommand(
      String command, FutureOr<String> Function(CommandArgs) callback) {
    commands[command.toLowerCase()] = callback;
  }

  /// Parse and execute a string, `msg` is the input. Optionally `inReplyTo` is the event being
  /// replied to and `editEventId` is the eventId of the event being replied to
  Future<String> parseAndRunCommand(Room room, String msg,
      {Event inReplyTo, String editEventId, String txid}) async {
    final args = CommandArgs(
      inReplyTo: inReplyTo,
      editEventId: editEventId,
      msg: '',
      room: room,
      txid: txid,
    );
    if (!msg.startsWith('/')) {
      if (commands.containsKey('send')) {
        args.msg = msg;
        return await commands['send'](args);
      }
      return null;
    }
    // remove the /
    msg = msg.substring(1);
    var command = msg;
    if (msg.contains(' ')) {
      final idx = msg.indexOf(' ');
      command = msg.substring(0, idx).toLowerCase();
      args.msg = msg.substring(idx + 1);
    } else {
      command = msg.toLowerCase();
    }
    if (commands.containsKey(command)) {
      return await commands[command](args);
    }
    if (msg.startsWith('/') && commands.containsKey('send')) {
      // re-set to include the "command"
      args.msg = msg;
      return await commands['send'](args);
    }
    return null;
  }

  /// Unregister all commands
  void unregisterAllCommands() {
    commands.clear();
  }

  /// Register all default commands
  void registerDefaultCommands() {
    addCommand('send', (CommandArgs args) async {
      return await args.room.sendTextEvent(
        args.msg,
        inReplyTo: args.inReplyTo,
        editEventId: args.editEventId,
        parseCommands: false,
        txid: args.txid,
      );
    });
    addCommand('me', (CommandArgs args) async {
      return await args.room.sendTextEvent(
        args.msg,
        inReplyTo: args.inReplyTo,
        editEventId: args.editEventId,
        msgtype: MessageTypes.Emote,
        parseCommands: false,
        txid: args.txid,
      );
    });
    addCommand('plain', (CommandArgs args) async {
      return await args.room.sendTextEvent(
        args.msg,
        inReplyTo: args.inReplyTo,
        editEventId: args.editEventId,
        parseMarkdown: false,
        parseCommands: false,
        txid: args.txid,
      );
    });
    addCommand('html', (CommandArgs args) async {
      final event = <String, dynamic>{
        'msgtype': 'm.text',
        'body': args.msg,
        'format': 'org.matrix.custom.html',
        'formatted_body': args.msg,
      };
      return await args.room.sendEvent(
        event,
        inReplyTo: args.inReplyTo,
        editEventId: args.editEventId,
        txid: args.txid,
      );
    });
    addCommand('react', (CommandArgs args) async {
      if (args.inReplyTo == null) {
        return null;
      }
      return await args.room.sendReaction(args.inReplyTo.eventId, args.msg);
    });
    addCommand('join', (CommandArgs args) async {
      await args.room.client.joinRoom(args.msg);
      return null;
    });
    addCommand('leave', (CommandArgs args) async {
      await args.room.leave();
      return '';
    });
    addCommand('op', (CommandArgs args) async {
      final parts = args.msg.split(' ');
      if (parts.isEmpty) {
        return null;
      }
      var pl = 50;
      if (parts.length >= 2) {
        pl = int.tryParse(parts[1]);
      }
      final mxid = parts.first;
      return await args.room.setPower(mxid, pl);
    });
    addCommand('kick', (CommandArgs args) async {
      final parts = args.msg.split(' ');
      await args.room.kick(parts.first);
      return '';
    });
    addCommand('ban', (CommandArgs args) async {
      final parts = args.msg.split(' ');
      await args.room.ban(parts.first);
      return '';
    });
    addCommand('unban', (CommandArgs args) async {
      final parts = args.msg.split(' ');
      await args.room.unban(parts.first);
      return '';
    });
    addCommand('invite', (CommandArgs args) async {
      final parts = args.msg.split(' ');
      await args.room.invite(parts.first);
      return '';
    });
    addCommand('myroomnick', (CommandArgs args) async {
      final currentEventJson = args.room
          .getState(EventTypes.RoomMember, args.room.client.userID)
          .content
          .copy();
      currentEventJson['displayname'] = args.msg;
      return await args.room.client.setRoomStateWithKey(
        args.room.id,
        EventTypes.RoomMember,
        currentEventJson,
        args.room.client.userID,
      );
    });
    addCommand('myroomavatar', (CommandArgs args) async {
      final currentEventJson = args.room
          .getState(EventTypes.RoomMember, args.room.client.userID)
          .content
          .copy();
      currentEventJson['avatar_url'] = args.msg;
      return await args.room.client.setRoomStateWithKey(
        args.room.id,
        EventTypes.RoomMember,
        currentEventJson,
        args.room.client.userID,
      );
    });
  }
}

class CommandArgs {
  String msg;
  String editEventId;
  Event inReplyTo;
  Room room;
  String txid;
  CommandArgs(
      {this.msg, this.editEventId, this.inReplyTo, this.room, this.txid});
}
