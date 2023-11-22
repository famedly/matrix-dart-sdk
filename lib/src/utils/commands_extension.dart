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
import 'dart:convert';

import 'package:matrix/matrix.dart';

extension CommandsClientExtension on Client {
  /// Add a command to the command handler. `command` is its name, and `callback` is the
  /// callback to invoke
  void addCommand(
      String command, FutureOr<String?> Function(CommandArgs) callback) {
    commands[command.toLowerCase()] = callback;
  }

  /// Parse and execute a string, `msg` is the input. Optionally `inReplyTo` is the event being
  /// replied to and `editEventId` is the eventId of the event being replied to
  Future<String?> parseAndRunCommand(
    Room room,
    String msg, {
    Event? inReplyTo,
    String? editEventId,
    String? txid,
    String? threadRootEventId,
    String? threadLastEventId,
  }) async {
    final args = CommandArgs(
      inReplyTo: inReplyTo,
      editEventId: editEventId,
      msg: '',
      room: room,
      txid: txid,
      threadRootEventId: threadRootEventId,
      threadLastEventId: threadLastEventId,
    );
    if (!msg.startsWith('/')) {
      final sendCommand = commands['send'];
      if (sendCommand != null) {
        args.msg = msg;
        return await sendCommand(args);
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
    final commandOp = commands[command];
    if (commandOp != null) {
      return await commandOp(args);
    }
    if (msg.startsWith('/') && commands.containsKey('send')) {
      // re-set to include the "command"
      final sendCommand = commands['send'];
      if (sendCommand != null) {
        args.msg = msg;
        return await sendCommand(args);
      }
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
        threadRootEventId: args.threadRootEventId,
        threadLastEventId: args.threadLastEventId,
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
        threadRootEventId: args.threadRootEventId,
        threadLastEventId: args.threadLastEventId,
      );
    });
    addCommand('dm', (CommandArgs args) async {
      final parts = args.msg.split(' ');
      return await args.room.client.startDirectChat(
        parts.first,
        enableEncryption: !parts.any((part) => part == '--no-encryption'),
      );
    });
    addCommand('create', (CommandArgs args) async {
      final parts = args.msg.split(' ');
      return await args.room.client.createGroupChat(
        enableEncryption: !parts.any((part) => part == '--no-encryption'),
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
        threadRootEventId: args.threadRootEventId,
        threadLastEventId: args.threadLastEventId,
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
      final inReplyTo = args.inReplyTo;
      if (inReplyTo == null) {
        return null;
      }
      return await args.room.sendReaction(inReplyTo.eventId, args.msg);
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
      int? pl;
      if (parts.length >= 2) {
        pl = int.tryParse(parts[1]);
      }
      final mxid = parts.first;
      return await args.room.setPower(mxid, pl ?? 50);
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
              .getState(EventTypes.RoomMember, args.room.client.userID!)
              ?.content
              .copy() ??
          {};
      currentEventJson['displayname'] = args.msg;
      return await args.room.client.setRoomStateWithKey(
        args.room.id,
        EventTypes.RoomMember,
        args.room.client.userID!,
        currentEventJson,
      );
    });
    addCommand('myroomavatar', (CommandArgs args) async {
      final currentEventJson = args.room
              .getState(EventTypes.RoomMember, args.room.client.userID!)
              ?.content
              .copy() ??
          {};
      currentEventJson['avatar_url'] = args.msg;
      return await args.room.client.setRoomStateWithKey(
        args.room.id,
        EventTypes.RoomMember,
        args.room.client.userID!,
        currentEventJson,
      );
    });
    addCommand('discardsession', (CommandArgs args) async {
      await encryption?.keyManager
          .clearOrUseOutboundGroupSession(args.room.id, wipe: true);
      return '';
    });
    addCommand('clearcache', (CommandArgs args) async {
      await clearCache();
      return '';
    });
    addCommand('markasdm', (CommandArgs args) async {
      final mxid = args.msg;
      if (!mxid.isValidMatrixId) {
        throw Exception('You must enter a valid mxid when using /maskasdm');
      }
      if (await args.room.requestUser(mxid, requestProfile: false) == null) {
        throw Exception('User $mxid is not in this room');
      }
      await args.room.addToDirectChat(args.msg);
      return;
    });
    addCommand('markasgroup', (CommandArgs args) async {
      await args.room.removeFromDirectChat();
      return;
    });
    addCommand('hug', (CommandArgs args) async {
      final content = CuteEventContent.hug;
      return await args.room.sendEvent(
        content,
        inReplyTo: args.inReplyTo,
        editEventId: args.editEventId,
        txid: args.txid,
      );
    });
    addCommand('googly', (CommandArgs args) async {
      final content = CuteEventContent.googlyEyes;
      return await args.room.sendEvent(
        content,
        inReplyTo: args.inReplyTo,
        editEventId: args.editEventId,
        txid: args.txid,
      );
    });
    addCommand('cuddle', (CommandArgs args) async {
      final content = CuteEventContent.cuddle;
      return await args.room.sendEvent(
        content,
        inReplyTo: args.inReplyTo,
        editEventId: args.editEventId,
        txid: args.txid,
      );
    });
    addCommand('sendRaw', (args) async {
      await args.room.sendEvent(
        jsonDecode(args.msg),
        inReplyTo: args.inReplyTo,
        txid: args.txid,
      );
      return null;
    });
  }
}

class CommandArgs {
  String msg;
  String? editEventId;
  Event? inReplyTo;
  Room room;
  String? txid;
  String? threadRootEventId;
  String? threadLastEventId;

  CommandArgs(
      {required this.msg,
      this.editEventId,
      this.inReplyTo,
      required this.room,
      this.txid,
      this.threadRootEventId,
      this.threadLastEventId});
}
