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

/// callback taking [CommandArgs] as input and a [StringBuffer] as standard output
/// optionally returns an event ID as in the [Room.sendEvent] syntax.
/// a [CommandException] should be thrown if the specified arguments are considered invalid
typedef CommandExecutionCallback = FutureOr<String?> Function(
  CommandArgs,
  StringBuffer? stdout,
);

extension CommandsClientExtension on Client {
  /// Add a command to the command handler. `command` is its name, and `callback` is the
  /// callback to invoke
  void addCommand(String command, CommandExecutionCallback callback) {
    commands[command.toLowerCase()] = callback;
  }

  /// Parse and execute a command on Client level
  /// - `room`: a [Room] to run the command on. Can be null unless you execute a command strictly requiring a [Room] to run on
  /// - `msg`: the complete input to process
  /// - `inReplyTo`: an optional [Event] the command is supposed to reply to
  /// - `editEventId`: an optional event ID the command is supposed to edit
  /// - `txid`: an optional transaction ID
  /// - `threadRootEventId`: an optional root event ID of a thread the command is supposed to run on
  /// - `threadLastEventId`: an optional most recent event ID of a thread the command is supposed to run on
  /// - `stdout`: an optional [StringBuffer] the command can write output to. This is meant as tiny implementation of https://en.wikipedia.org/wiki/Standard_streams in order to process advanced command output to the matrix client. See [DefaultCommandOutput] for a rough idea.
  Future<String?> parseAndRunCommand(
    Room? room,
    String msg, {
    Event? inReplyTo,
    String? editEventId,
    String? txid,
    String? threadRootEventId,
    String? threadLastEventId,
    StringBuffer? stdout,
  }) async {
    final args = CommandArgs(
      inReplyTo: inReplyTo,
      editEventId: editEventId,
      msg: '',
      client: this,
      room: room,
      txid: txid,
      threadRootEventId: threadRootEventId,
      threadLastEventId: threadLastEventId,
    );
    if (!msg.startsWith('/')) {
      final sendCommand = commands['send'];
      if (sendCommand != null) {
        args.msg = msg;
        return await sendCommand(args, stdout);
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
      return await commandOp(args, stdout);
    }
    if (msg.startsWith('/') && commands.containsKey('send')) {
      // re-set to include the "command"
      final sendCommand = commands['send'];
      if (sendCommand != null) {
        args.msg = msg;
        return await sendCommand(args, stdout);
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
    addCommand('send', (args, stdout) async {
      final room = args.room;
      if (room == null) {
        throw RoomCommandException();
      }
      return await room.sendTextEvent(
        args.msg,
        inReplyTo: args.inReplyTo,
        editEventId: args.editEventId,
        parseCommands: false,
        txid: args.txid,
        threadRootEventId: args.threadRootEventId,
        threadLastEventId: args.threadLastEventId,
      );
    });
    addCommand('me', (args, stdout) async {
      final room = args.room;
      if (room == null) {
        throw RoomCommandException();
      }
      return await room.sendTextEvent(
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
    addCommand('dm', (args, stdout) async {
      final parts = args.msg.split(' ');
      final mxid = parts.first;
      if (!mxid.isValidMatrixId) {
        throw CommandException('You must enter a valid mxid when using /dm');
      }

      final roomId = await args.client.startDirectChat(
        mxid,
        enableEncryption: !parts.any((part) => part == '--no-encryption'),
      );
      stdout?.write(
        DefaultCommandOutput(
          rooms: [roomId],
          users: [mxid],
        ).toString(),
      );
      return null;
    });
    addCommand('create', (args, stdout) async {
      final groupName = args.msg.replaceFirst('--no-encryption', '').trim();

      final parts = args.msg.split(' ');

      final roomId = await args.client.createGroupChat(
        groupName: groupName.isNotEmpty ? groupName : null,
        enableEncryption: !parts.any((part) => part == '--no-encryption'),
        waitForSync: false,
      );
      stdout?.write(DefaultCommandOutput(rooms: [roomId]).toString());
      return null;
    });
    addCommand('plain', (args, stdout) async {
      final room = args.room;
      if (room == null) {
        throw RoomCommandException();
      }
      return await room.sendTextEvent(
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
    addCommand('html', (args, stdout) async {
      final event = <String, dynamic>{
        'msgtype': 'm.text',
        'body': args.msg,
        'format': 'org.matrix.custom.html',
        'formatted_body': args.msg,
      };
      final room = args.room;
      if (room == null) {
        throw RoomCommandException();
      }
      return await room.sendEvent(
        event,
        inReplyTo: args.inReplyTo,
        editEventId: args.editEventId,
        txid: args.txid,
      );
    });
    addCommand('react', (args, stdout) async {
      final inReplyTo = args.inReplyTo;
      if (inReplyTo == null) {
        return null;
      }
      final room = args.room;
      if (room == null) {
        throw RoomCommandException();
      }
      final parts = args.msg.split(' ');
      final reaction = parts.first.trim();
      if (reaction.isEmpty) {
        throw CommandException('You must provide a reaction when using /react');
      }
      return await room.sendReaction(inReplyTo.eventId, reaction);
    });
    addCommand('join', (args, stdout) async {
      final roomId = await args.client.joinRoom(args.msg);
      stdout?.write(DefaultCommandOutput(rooms: [roomId]).toString());
      return null;
    });
    addCommand('leave', (args, stdout) async {
      final room = args.room;
      if (room == null) {
        throw RoomCommandException();
      }
      await room.leave();
      return null;
    });
    addCommand('op', (args, stdout) async {
      final room = args.room;
      if (room == null) {
        throw RoomCommandException();
      }
      final parts = args.msg.split(' ');
      if (parts.isEmpty || !parts.first.isValidMatrixId) {
        throw CommandException('You must enter a valid mxid when using /op');
      }
      int? pl;
      if (parts.length >= 2) {
        pl = int.tryParse(parts[1]);
        if (pl == null) {
          throw CommandException(
            'Invalid power level ${parts[1]} when using /op',
          );
        }
      }
      final mxid = parts.first;
      return await room.setPower(mxid, pl ?? 50);
    });
    addCommand('kick', (args, stdout) async {
      final room = args.room;
      if (room == null) {
        throw RoomCommandException();
      }
      final parts = args.msg.split(' ');
      final mxid = parts.first;
      if (!mxid.isValidMatrixId) {
        throw CommandException('You must enter a valid mxid when using /kick');
      }
      await room.kick(mxid);
      stdout?.write(DefaultCommandOutput(users: [mxid]).toString());
      return null;
    });
    addCommand('ban', (args, stdout) async {
      final room = args.room;
      if (room == null) {
        throw RoomCommandException();
      }
      final parts = args.msg.split(' ');
      final mxid = parts.first;
      if (!mxid.isValidMatrixId) {
        throw CommandException('You must enter a valid mxid when using /ban');
      }
      await room.ban(mxid);
      stdout?.write(DefaultCommandOutput(users: [mxid]).toString());
      return null;
    });
    addCommand('unban', (args, stdout) async {
      final room = args.room;
      if (room == null) {
        throw RoomCommandException();
      }
      final parts = args.msg.split(' ');
      final mxid = parts.first;
      if (!mxid.isValidMatrixId) {
        throw CommandException('You must enter a valid mxid when using /unban');
      }
      await room.unban(mxid);
      stdout?.write(DefaultCommandOutput(users: [mxid]).toString());
      return null;
    });
    addCommand('invite', (args, stdout) async {
      final room = args.room;
      if (room == null) {
        throw RoomCommandException();
      }

      final parts = args.msg.split(' ');
      final mxid = parts.first;
      if (!mxid.isValidMatrixId) {
        throw CommandException(
          'You must enter a valid mxid when using /invite',
        );
      }
      await room.invite(mxid);
      stdout?.write(DefaultCommandOutput(users: [mxid]).toString());
      return null;
    });
    addCommand('myroomnick', (args, stdout) async {
      final room = args.room;
      if (room == null) {
        throw RoomCommandException();
      }

      final currentEventJson = room
              .getState(EventTypes.RoomMember, args.client.userID!)
              ?.content
              .copy() ??
          {};
      currentEventJson['displayname'] = args.msg;

      return await args.client.setRoomStateWithKey(
        room.id,
        EventTypes.RoomMember,
        args.client.userID!,
        currentEventJson,
      );
    });
    addCommand('myroomavatar', (args, stdout) async {
      final room = args.room;
      if (room == null) {
        throw RoomCommandException();
      }

      final currentEventJson = room
              .getState(EventTypes.RoomMember, args.client.userID!)
              ?.content
              .copy() ??
          {};
      currentEventJson['avatar_url'] = args.msg;

      return await args.client.setRoomStateWithKey(
        room.id,
        EventTypes.RoomMember,
        args.client.userID!,
        currentEventJson,
      );
    });
    addCommand('discardsession', (args, stdout) async {
      final room = args.room;
      if (room == null) {
        throw RoomCommandException();
      }
      await encryption?.keyManager
          .clearOrUseOutboundGroupSession(room.id, wipe: true);
      return null;
    });
    addCommand('clearcache', (args, stdout) async {
      await clearCache();
      return null;
    });
    addCommand('markasdm', (args, stdout) async {
      final room = args.room;
      if (room == null) {
        throw RoomCommandException();
      }

      final mxid = args.msg.split(' ').first;
      if (!mxid.isValidMatrixId) {
        throw CommandException(
          'You must enter a valid mxid when using /maskasdm',
        );
      }
      if (await room.requestUser(mxid, requestProfile: false) == null) {
        throw CommandException('User $mxid is not in this room');
      }
      await room.addToDirectChat(mxid);
      stdout?.write(DefaultCommandOutput(users: [mxid]).toString());
      return null;
    });
    addCommand('markasgroup', (args, stdout) async {
      final room = args.room;
      if (room == null) {
        throw RoomCommandException();
      }

      await room.removeFromDirectChat();
      return;
    });
    addCommand('hug', (args, stdout) async {
      final content = CuteEventContent.hug;
      final room = args.room;
      if (room == null) {
        throw RoomCommandException();
      }
      return await room.sendEvent(
        content,
        inReplyTo: args.inReplyTo,
        editEventId: args.editEventId,
        txid: args.txid,
      );
    });
    addCommand('googly', (args, stdout) async {
      final content = CuteEventContent.googlyEyes;
      final room = args.room;
      if (room == null) {
        throw RoomCommandException();
      }
      return await room.sendEvent(
        content,
        inReplyTo: args.inReplyTo,
        editEventId: args.editEventId,
        txid: args.txid,
      );
    });
    addCommand('cuddle', (args, stdout) async {
      final content = CuteEventContent.cuddle;
      final room = args.room;
      if (room == null) {
        throw RoomCommandException();
      }
      return await room.sendEvent(
        content,
        inReplyTo: args.inReplyTo,
        editEventId: args.editEventId,
        txid: args.txid,
      );
    });
    addCommand('sendRaw', (args, stdout) async {
      final room = args.room;
      if (room == null) {
        throw RoomCommandException();
      }
      return await room.sendEvent(
        jsonDecode(args.msg),
        inReplyTo: args.inReplyTo,
        txid: args.txid,
      );
    });
    addCommand('ignore', (args, stdout) async {
      final mxid = args.msg;
      if (mxid.isEmpty) {
        throw CommandException('Please provide a User ID');
      }
      await ignoreUser(mxid);
      stdout?.write(DefaultCommandOutput(users: [mxid]).toString());
      return null;
    });
    addCommand('unignore', (args, stdout) async {
      final mxid = args.msg;
      if (mxid.isEmpty) {
        throw CommandException('Please provide a User ID');
      }
      await unignoreUser(mxid);
      stdout?.write(DefaultCommandOutput(users: [mxid]).toString());
      return null;
    });
    addCommand('roomupgrade', (args, stdout) async {
      final version = args.msg;
      if (version.isEmpty) {
        throw CommandException('Please provide a room version');
      }
      final newRoomId =
          await args.room!.client.upgradeRoom(args.room!.id, version);
      stdout?.write(DefaultCommandOutput(rooms: [newRoomId]).toString());
      return null;
    });
    addCommand('logout', (args, stdout) async {
      await logout();
      return null;
    });
    addCommand('logoutAll', (args, stdout) async {
      await logoutAll();
      return null;
    });
  }
}

class CommandArgs {
  String msg;
  String? editEventId;
  Event? inReplyTo;
  Client client;
  Room? room;
  String? txid;
  String? threadRootEventId;
  String? threadLastEventId;

  CommandArgs({
    required this.msg,
    this.editEventId,
    this.inReplyTo,
    required this.client,
    this.room,
    this.txid,
    this.threadRootEventId,
    this.threadLastEventId,
  });
}

class CommandException implements Exception {
  final String message;

  const CommandException(this.message);

  @override
  String toString() {
    return '${super.toString()}: $message';
  }
}

class RoomCommandException extends CommandException {
  const RoomCommandException() : super('This command must run on a room');
}

/// Helper class for normalized command output
///
/// This class can be used to provide a default, processable output of commands
/// containing some generic data.
///
/// NOTE: Please be careful whether to include event IDs into the output.
///
/// If your command actually sends an event to a room, please do not include
/// the event ID here. The default behavior of the [Room.sendTextEvent] is to
/// return the event ID of the just sent event. The [DefaultCommandOutput.events]
/// field is not supposed to replace/duplicate this behavior.
///
/// But if your command performs an action such as search, highlight or anything
/// your matrix client should display different than adding an event to the
/// [Timeline], you can include the event IDs related to the command output here.
class DefaultCommandOutput {
  static const format = 'com.famedly.default_command_output';
  final List<String>? rooms;
  final List<String>? events;
  final List<String>? users;
  final List<String>? messages;
  final Map<String, Object?>? custom;

  const DefaultCommandOutput({
    this.rooms,
    this.events,
    this.users,
    this.messages,
    this.custom,
  });

  static DefaultCommandOutput? fromStdout(String stdout) {
    final Object? json = jsonDecode(stdout);
    if (json is! Map<String, Object?>) {
      return null;
    }
    if (json['format'] != format) return null;
    return DefaultCommandOutput(
      rooms: json['rooms'] == null
          ? null
          : List<String>.from(json['rooms'] as Iterable),
      events: json['events'] == null
          ? null
          : List<String>.from(json['events'] as Iterable),
      users: json['users'] == null
          ? null
          : List<String>.from(json['users'] as Iterable),
      messages: json['messages'] == null
          ? null
          : List<String>.from(json['messages'] as Iterable),
      custom: json['custom'] == null
          ? null
          : Map<String, Object?>.from(json['custom'] as Map),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'format': format,
      if (rooms != null) 'rooms': rooms,
      if (events != null) 'events': events,
      if (users != null) 'users': users,
      if (messages != null) 'messages': messages,
      ...?custom,
    };
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}
