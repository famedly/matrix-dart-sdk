## [0.8.4] - 08nd Feb 2022
- fix: Call onChange correctly on redacted aggregation events

## [0.8.3] - 07nd Feb 2022
- fix: Remove onHistoryReceived which was broken anyway
- fix: Remove aggregation event doesnt trigger onChange

## [0.8.2] - 04nd Feb 2022
- fix: Add redaction events to timeline
- fix: Resize image with compute by using const class arguments

## [0.8.1] - 03nd Feb 2022
- refactor: Implement on history received in timeline
- fix: null-safety issues with widgets
- fix: Trigger onChange for index on aggregation event update
- feat: implement to get a room's widgets

## [0.8.0] - 25nd Jan 2022
- BREAKING CHANGE: high-level hadling of image sizes
- feat: expose Timeline.onChange to Room.getTimeline
- fix: Use where and map instead of a loop and a removeWhere
- fix: Remove sorts that shouldnt be required.

## [0.7.3] - 14nd Jan 2022
- fix: Fix turn credentials format issue for safari.
- fix: update fluffybox version to correctly clear rooms after logout. 
- fix: Allow unpadded base64 decoding

## [0.7.2] - 08nd Jan 2022
- feat: Let sendDefaultMessage return false on encryption failure (Krille Fear)
- fix: Room Member updates should always be cached (Krille Fear)
- fix: Requested users are not stored (Christian Pauly)
- fix: Localize reactions (Krille Fear)
- refactor: Remove unnecessary type checks and imports (Krille Fear)

## [0.7.1] - 08nd Dec 2021
- fix: fallback in body for replies to replies (Nicolas Werner)
- fix: ignore 4xx errors when re-sending the to_device queue The to_device queue was introduced to ensure integrity if e.g. the server temporarily failed when attempting to send a to_device message. If, for whatever reason, the server responds with a 4xx error, though, then we want to ignore that to_device message from the queue and move on, as that means that something different was fundamentally wrong. This helps to fix the to_device queue clogging up, making clients incapable of sending to_device events anymore, should such clogging happen. (Sorunome)
- fix: Database corruptions by updating FluffyBox (Krille Fear)
- fix: Store the call state, fix the invite cannot be sent. (cloudwebrtc)
- fix: Allow consecutive edits for state events in-memory The lastEvent was incorrect when trying to process an edit of an edit. This fixes that by allowing consecutive edits for the last event. (Sorunome)
- fix: Only save state events from sync processing in-memory if needed If we dump all state events from sync into memory then we needlessly clog up our memory, potentially running out of ram. This is useless as when opening the timeline we post-load the unimportant state events anyways. So, this PR makes sure that only the state events of post-loaded rooms and important state events land in-memory when processing a sync request. (Sorunome)
- fix(ssss): Strip all whitespace characters from recovery keys upon decode Previously we stripped all spaces off of the recovery when decoding it, so that we could format the recovery key nicely. It turns out, however, that some element flavours also format with linebreaks, leading to the user having to manually remove them. We fix this by just stripping *all* whitespace off of the recovery key. (Sorunome)

## [0.7.0] - 03nd Dec 2021
- feat: Support for webRTC
- fix: Add missing calcDisplayname global rules to client constructor

## [0.7.0-nullsafety.10] - 26nd Nov 2021
- feat: Migrate olm sessions on database migration
- chore: Enable E2EE recovery by default

## [0.7.0-nullsafety.9] - 25nd Nov 2021
- fix: Limited timeline clean up on web
- fix: Remove account avatar

## [0.7.0-nullsafety.8] - 24nd Nov 2021
- chore: Update FluffyBox

## [0.7.0-nullsafety.7] - 23nd Nov 2021
- feat: Add commands to create chats
- feat: Add clear cache command
- feat: Implement new FluffyBox database API implementation
- fix: Workaround for a null exception for a non nullable boolean while user device key updating
- fix: Limited timeline clears too many events
- fix: Ability to remove avatar from room and account
- fix: Request history in archived rooms
- fix: Decrypt last event of a room
- refactor: Remove Sembast database implementation

## [0.7.0-nullsafety.6] - 16nd Nov 2021
- feat: Implement sembast store
- fix: HtmlToText crashes with an empty code block
- fix: use originServerTs to check if state event is old
- fix: Dont enable e2ee in new direct chats without encryption support
- fix: Change eventstatus of edits in prevEvent
- chore: Trim formatted username fallback

## [0.7.0-nullsafety.5] - 10nd Nov 2021
- fix: Edits as lastEvent do not update
- fix: JSON parsing in decryptRoomEvent method
- fix: Wrong null check in hive database
- fix: crash on invalid displaynames
- chore: Update matrix_api_lite

## [0.7.0-nullsafety.4] - 09nd Nov 2021
- feat: More advanced create chat methods (encryption is now enabled by default)
- feat: Make waiting on init db optional
- feat: Add more benchmarks for sync, timeline, init
- feat: Add onInsert, onRemove and onUpdate cb to timeline
- refactor: Move setreadmarker functionality to timeline

## [0.7.0-nullsafety.3] - 05nd Nov 2021
- fix: Null error in get own profile

## [0.7.0-nullsafety.2] - 04nd Nov 2021
- refactor: Make room in Event class not nullable
- refactor: download method should not return null

## [0.7.0-nullsafety.1] - 04nd Nov 2021
Prerelease of the null safety version of the SDK.
- feat: choose memberships returned by requestParticipants()
- refactor: Make SDK null safe
- fix: add room invite update to roomStateBox, so invites don't show empty room when app is restarted
- fix: Do not upload keys after logout
- fix: obay explicitly set ports in mxc URLs

## [0.6.2] - 25nd Oct 2021
- fix: Unnecessary null check
- fix: Auto update room states

## [0.6.1] - 18nd Oct 2021
- fix: Missing null check in a nested json map

## [0.6.0] - 15nd Oct 2021
- feat: Calc benchmarks for hive operations on init
- refactor: Change event status to enum
- refactor: Migrate more files to null safety
- fix: Type error when using CryptoKey in dart web
- fix: events with unknown users having invalid mxids This caused issues down the line where the sender id was assumed to be a valid matrix identifier
- fix: Sent events are sorted in SENDING timeline
- fix: use explicit type in fold instead of cast
- fix: apply review feedback
- fix: missing range check When requesting history the `start` parameter could become larger than the loaded events from the database were, resulting in an error when attempting to request history.
- fix: New verification requests on requesting history
- refactor: remove unused clientId
- fix: Add type checkings for User.displayName

## [0.5.5] - 20nd Sep 2021
 fix: Autodetect mime type on file upload

## [0.5.4] - 20nd Sep 2021
- feat: Add waitForFirstSync parameter to init method

## [0.5.3] - 19nd Sep 2021
- feat: Add /discardsession command
- fix: Auto-reply key requests
- fix: Room previews not showing replies
- fix: missing content-type when changing avatar
- fix: only/number emotes in a reply

## [0.5.2] - 14nd Sep 2021
- fix: Delete box if it can not be cleared when calling database.clear() -> This should fix some box corruption problems
- fix: Do not set old events as state events -> This should fix the room list sort ordering bug

## [0.5.1] - 13nd Sep 2021
- fix: Room.notificationCount set to null sometimes

## [0.5.0] - 13nd Sep 2021
- hotfix: Key sharing security vulnerability! -> Please upgrade as soon as possible to this version
- feat: MSC2746: Improved Signalling for 1:1 VoIP
- fix: Get direct chat from user ID method crashes on more than one DM rooms with one account
- fix: compilation against newer matrix_api_lite
- refactor: Remove onRoomUpdate stream

## [0.4.3] - 8nd Sep 2021
- fix: Do not handle sending event updates which are already synced

## [0.4.2] - 6nd Sep 2021
- revert: Make bytes in EncryptedFile nullable

## [0.4.1] - 6nd Sep 2021
- fix: Make bytes in EncryptedFile nullable

## [0.4.0] - 3nd Sep 2021
- fix: Check if database got disposed in keyManager
- fix: Implement dummy transactions for hive
- fix: room account data key/type returned encoded
- fix: Missing null check
- fix: uiaRequests send broken auth object at first try
- fix: Requesting history being funky
- fix: Don't lag when sending messages in big rooms
- feat: Do not load all timeline events from store at once
- feat: Pin invited rooms
- refactor: Replace all logic regarding sortOrder
- refactor: Workarounds for missing mHeroes in rooms

## [0.3.6] - 30nd Aug 2021
- hotfix: uiaRequests send broken auth object at first try

## [0.3.5] - 28nd Aug 2021
- hotfix: Send unencrypted thumbnails

## [0.3.4] - 28nd Aug 2021
- fix: String.parseIdentifierIntoParts not working with unicode matrix.to links
    Some clients do not uri-encode the identifier for matrix.to links, so we must
    handle if we can't uri-decode them
- fix: missing null check in hideEdit condition
- fix: missing null check
    It seems `device_keys` in the reply of `/keys/query` is not required. While synapse always
    sent it, conduit did not, which resulted in an error.

## [0.3.3] - 20nd Aug 2021
- fix: room.lastEvent order now respects edits
- feat: use m.new_content in lastEvent (so no more * fallback)

## [0.3.2] - 20nd Aug 2021
- feat: cache archived rooms to access them with `getRoomById`
- fix: requestHistory() for archived rooms
- refactor: Change name of archive getter to function

## [0.3.1] - 20nd Aug 2021
- hotfix: Opt-out null safety for crypto files because of an error in web

## [0.3.0] - 20nd Aug 2021
- remove: deprecated moor database (breaking change)
- feat(events): add plain-text body representation from HTML
- feat: get new_content in getLocalizedBody
- feat: Add a way to get a verification request by its transaction id
    A client might find the need to get the verification request object by
    its transaction id, to be able to e.g. display for in-room verification
    an "accept verification request" button easily.
- fix: Correctly parse the reason of a spoiler
    Previously only the first child node of a spoiler was considered to
    determine if there should be a spoiler reason. This was, unfortunately,
    incorrect, as soon as e.g. the reason had more than one space. This is
    fixed by properly iterating all child nodes to search for the reason.
- fix: Add space states to important events
    We need the space state events in the important events to be able to
    differentiate rooms and spaces in the room list.
- feat: Allow specifying extraContent for Room.sendFileEvent, in case clients want to specify some custom stuff
- fix: toDouble was called on null when you had a pinned room
- fix: Typo in key backup requests
    This may lead to messages not decrypting after interactive verification,
    which would make the user manually press the request keys button.
- refactor: rename LoginState.logged to loggedIn

## [0.2.1] - 2nd Aug 2021

- fix: accidental OTK uploads on fakeSync calls

## [0.2.0] - 27th Jul 2021

- Breaking API changes duo to use of code generated matrix API
- fix: Missing null checks in syncUpdate handling

## [0.1.11] - 26th Jul 2021

- fix: Upload OTKs if the otk_count field is missing

## [0.1.10] - 21th Jul 2021

Please note: This removes the isolate code from the SDK to make it compatible with dart web. If
you still want the SDK to execute code in the background to not block the UI on key generation
for example, pass the `compute` method from Flutter to your client:

```dart
// ...
final client = Client('name...',
    // ...
    compute: compute,
);
```

## [0.1.9] - 20th Jul 2021

- fix: Add missing null check which made bootstrap fail for newest Synapse release

## [0.1.8] - 18th Jul 2021

- fix: Provide a reasonable well-known fallback
- fix: Add locking to sending encrypted to_device messages to prevent potential race conditions
- fix: preserve homeserver port when creating thumbnail URIs
- feat: Add support for nicer mentions
- feat: Add general image pack handling as per MSC2545

## [0.1.7] - 10 Jul 2021

- change: Hive database schema (will trigger a database migration)
- fix: Dont migrate database from version null
- fix: Adjust emoji ranges to have less false positives
- fix: Sending of the to_device key

## [0.1.6] - 06 Jul 2021

- feat: Make it possible to get the current loginState
- fix: Broken nested accountData content maps
- fix: Mark unsent events as failed
- fix: Pin moor to 4.3.2 to fix the CI errors

## [0.1.5] - 26 Jun 2021

- fix: Don't run syncs while the client is being initialized

## [0.1.4] - 19 Jun 2021

- change: Replace onSyncError Stream with onSyncStatus

## [0.1.3] - 19 Jun 2021

- feat: Implement migration for hive schema versions

## [0.1.2] - 19 Jun 2021

- fix: Hive breaks if room IDs contain emojis (yes there are users with hacked synapses out there who needs this)
- feat: Also migrate inbound group sessions

## [0.1.1] - 18 Jun 2021

- refactor: Move pedantic to dev_dependencies
- chore: Update readme
- fix: Migrate missing device keys

## [0.1.0] - 17 Jun 2021

First stable version
