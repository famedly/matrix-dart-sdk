## Available Chat Commands

The Matrix Dart SDK supports out of the box chat commands. Just use `Room.sendTextEvent("/command");`. If you do not desire to get chat commands parsed, you can disable them like this: `Room.sendTextEvent("/command", parseCommands: false);`

### Available Commands:

## Available Chat Commands

The Matrix Dart SDK supports out of the box chat commands. Just use `Room.sendTextEvent("/command");`. If you do not desire to get chat commands parsed, you can disable them like this: `Room.sendTextEvent("/command", parseCommands: false);`

### Available Commands:

```sh
/send <message>
```
Sends a plain message to the current room (commands are not parsed).

```sh
/me <action>
```
Sends an emote message (e.g., `/me is happy` will display as "YourName is happy").

```sh
/dm <mxid> [--no-encryption]
```
Starts a direct chat with the given user. Optionally disables encryption.

```sh
/create [<group name>] [--no-encryption]
```
Creates a new group chat with the given name. Optionally disables encryption.

```sh
/plain <message>
```
Sends a plain text message (no markdown, no commands) to the current room.

```sh
/html <html>
```
Sends a message as raw HTML to the current room.

```sh
/react <emoji>
```
Reacts to the message you are replying to with the given emoji.

```sh
/join <room>
```
Joins the specified room.

```sh
/leave
```
Leaves the current room.

```sh
/op <mxid> [<power level>]
```
Sets the power level of a user in the current room (default: 50).

```sh
/kick <mxid>
```
Kicks a user from the current room.

```sh
/ban <mxid>
```
Bans a user from the current room.

```sh
/unban <mxid>
```
Unbans a user in the current room.

```sh
/invite <mxid>
```
Invites a user to the current room.

```sh
/myroomnick <displayname>
```
Sets your display name in the current room.

```sh
/myroomavatar <mxc-url>
```
Sets your avatar in the current room.

```sh
/discardsession
```
Discards the outbound group session for the current room (forces new encryption session).

```sh
/clearcache
```
Clears the local cache.

```sh
/markasdm <mxid>
```
Marks the current room as a direct chat with the given user.

```sh
/markasgroup
```
Removes the direct chat status from the current room.

```sh
/hug
```
Sends a "hug" event to the current room.

```sh
/googly
```
Sends a "googly eyes" event to the current room.

```sh
/cuddle
```
Sends a "cuddle" event to the current room.

```sh
/sendRaw <json>
```
Sends a raw event (as JSON) to the current room.

```sh
/ignore <mxid>
```
Ignores the given user (you will not see their messages).

```sh
/unignore <mxid>
```
Stops ignoring the given user.

```sh
/roomupgrade <version>
```
Upgrades the current room to a new version.

```sh
/logout
```
Logs out the current session.

```sh
/logoutAll
```
Logs out all sessions for the user.