## [0.22.2] - 6 August 2023

- fix: direct message room name computation (The one with the braid)
- refactor: simplify UIA stage selection logic (Nicolas Werner)
- feat: Upload keys on OKB reset (Nicolas Werner)
- fix: fix upload of old session after reset (Nicolas Werner)
- refactor: Simplify room sorting logic to make invite sorting more obvious (Nicolas Werner)

## [0.22.1] - 19th July 2023

- chore: add pub release job (td)
- chore: add dependabot (Niklas Zender)
- feat: Use github actions (Nicolas Werner)
- fix: do not proceed call if getUserMedia fails (td)

## [0.22.0] - 4th July 2023

- chore: pass event to redactedAnEvent and removedBy (td)

## [0.21.2] - 27th June 2023

- chore: cleanup some eventTypes and unused variables (td)
- chore: fix unexpected null when device is not known (td)

## [0.21.1] - 22nd June 2023

- fix: Assign correct type to signedOneTimeKeys (Malin Errenst)

## [0.21.0] - 21st June 2023

- feat: qr key verification (td)
- refactor: Use tryGet for type casts whenever possible (Malin Errenst)
- chore: Update matrix_api_lite to 1.7.0 (Malin Errenst)
- refactor: Added type casts to match refactored matrix_api_lite (Malin Errenst)
- refactor: Added type casts for refactored dart_openapi_codegen (Malin Errenst)
- builds: Pin matrix api lite (Krille)
- fix: Do not display prevContent displayname and avatar for joined users (Krille)
- builds: Update dart and flutter ci containers (Krille)
- fix: canRequestHistory should return false if prev_batch is null (Krille)

## [0.20.5] - 2th June 2023

- chore: fix edited last events breaking db (td)

## [0.20.4] - 31th May 2023

- fix: Do not store global profiles in room states as members (Krille)

## [0.20.3] - 30th May 2023

- feat: Display performance warning when requesting more than 100 participants (Krille)
- fix: Also update last event on redaction in store (Krille)
- refactor: Let bootstrap throw custom Exception InvalidPassphraseException so it is easier to catch (Krille)

## [0.20.2] - 17th May 2023

- builds: Update to flutter container 3.7.12 (Krille)
- chore: add missing awaits to to_device call events listener (td)
- chore: add missing awaits to to_device call events listener (td)
- chore: calculate unlocalized body (Reza)
- fix: mark DMs as DMs properly when joining (Nicolas Werner)
- fix: remove deprecated sender_key occurrences (Malin Errenst)
- refactor: Check correct if null (Krille)
- refactor: Remove unused parameters (Krille)

## [0.20.1] - 5th May 2023

- fix: cast issues in getEventList (td)
- refactor: Make parameters more clear and remove unused methods (Krille)
- fix: Only request users which are valid mxid (Krille)
- fix: Always wait for account data to load before returning SSSS status (Nicolas Werner)
- fix: Reactions are sent encrypted (Krille)
- chore: oneShotSync before staleCallChecker (td)
- fix: updateMuteStatus after kConnected (td)

## [0.20.0] - 28th April 2023

- refactor: Make optional eventId a named parameter (Krille)
- fix: Check the max server file size after shrinking not before (Krille)
- fix: casting of a List<dynamic> to List<String> in getEventList and getEventIdList (td)
- fix: Skip rules with unknown conditions (Nicolas Werner)
- fix: allow passing a WrappedMediaStream to GroupCall.enter() to use as the local user media stream (td)

## [0.19.0] - 21st April 2023

This includes some breaking changes to read receipts. You won't be able to
access the `m.receipt` account data pseudo event anymore. This has been replaces
with a per room `receiptsState`, that also supports private and threaded
receipts. Additionally you can now toggle if receipts are sent as public or
private receipts on the client level.

- chore: Update image dependency to 4.0.15 (Kristian Grønås)
- feat: Support private read receipts (Nicolas Werner)

## [0.18.4] - 21st April 2023

- chore: bump api_lite to 16.1 (td)
- feat: allow sending messages inside threads (Dmitriy Bragin)
- chore: Upgrade to matrix_api_lite 1.6 (Nicolas Werner)
- ci: Allow overriding the template in a manual or triggered pipeline (Nicolas Werner)

## [0.18.3] - 13th April 2023

- chore: stopMediaStream on all streams and make sure dispose runs everytime (td)
- fix: test if setting track enabled on participants changed helps with the media not working randomly issue (td)

## [0.18.2] - 31th March 2023

- chore: Update to flutter image 3.7.8 (Krille)
- chore: Workaround for broken test dependency (Krille)
- chore: ignore stale call checking for archived rooms (td)
- feat: Implement onMigration callback to Client.init() method (Krille)
- fix: Clear HiveCollection boxes inside of transaction in order (Krille)
- refactor: Rename one-character-variables in device_keys_list.dart (Malin Errenst)

## [0.18.1] - 20th March 2023

- feat: Allow accessing cached archive rooms as well as request keys for them (Philipp Grieshofer)
- feat: Make possible to overwrite boxcollection opener in Hive Collections Database (Krille)
- fix: Use MatrixLocalizations to calculate fallback user displayname (Philipp Grieshofer)

## [0.18.0] - 6th March 2023

- chore: remove checker from local list (td)
- chore: stop stale group call checker on room leave (td)
- chore: update. (cloudwebrtc)
- feat: Implement pagination for searchEvent endpoint (Christian Pauly)
- fix: archive takes 2 minutes to update (Nicolas Werner)
- fix: http api call replaced with httpClient (m_kushal)
- fix: BREAKING CHANGE make group call stuff async, let clients await what they need (voip callbacks like handleNewCall, handleCallEnded need to be Future<void> now) (td)
- fix: skip invalid candidate. (cloudwebrtc)

## [0.17.1] - 20th Feb 2023

- chore: add missing awaits in group call enter and leave funcs (td)
- chore: add useServerCache option to fetchOwnProfileFromServer and fix missing awaits (td)

## [0.17.0] - 17th Feb 2023

- fix: ability to upgrade audio calls to video calls (td)
- chore: add a fetchOwnProfileFromServer method which tries to get ownProfile from server first, disk then (td)
- fix: clean expired member state events in group calls (td)
- fix: hasActiveGroup call now checks all group calls (td)
- fix: Check if argument is valid mxid in /maskasdm command (Christian Pauly)
- fix: Fake User object (Christian Pauly)
- fix: Request key in searchEvent method crashes because of wrong preconditions (Christian Pauly)
- refactor: Check config at file sending after placing fake event and add error handling (Krille)
- chore: bump dart to 2.18 (Nicolas Werner)
- fix: setMicrophoneMuted is now async to match setVideoMuted (td)
- fix: implement activeGroupCallEvents to get all active group call state events in a room (td)
- refactor: (BREAKING CHANGE) move staleCallChecker and expires_Ts stuff to an extension on Room, instead of Voip because it makes much more sense per room rather than on voip, also makes testing easier (td)
- fix: populate local groupCalls list on instantiating VOIP() (td)
- fix: starting stale call checker is now handled by the sdk itself because clients can forget to do so (td)

## [0.16.0] - 1st Feb 2023

- chore: bump flutter and dart images (td)
- fix: move expires_ts according to spec (breaks group call compatibility with older sdks) (td)
- fix: reject call on own device if you get a call reject (td)
- feat: active speaker in group calls (td)
- fix: missed incomingCallRoomId case in removing glare stuff during group calls (td)
- fix: fix glare side effects for group calls. (Duan Weiwei)
- chore: bump version (td)
- chore: deprecate isBackground (td)
- fix: try to stop ringtone on call termination (td)
- fix: Fix can't correctly remove/cleanup call in group call. (Duan Weiwei)
- fix: send all servers for getIceServers (td)
- fix: only send call reject event when needed (td)
- fix: use tagged dart images in ci (td)

## [0.15.13] - 23rd Jan 2023

- fix: glare (td)
- fix: update groupCalls state stream (td)
- fix: tweak some stuff in group calls code for group calls onboarding feat (td)
- feat: add method to generate the matrix.to link (td)
- fix: follow-up OLM matcher (The one with the braid)
- refactor: migrate integration tests to more stable setup (TheOneWithTheBraid)

## [0.15.12] - 18th Jan 2023

This deprecates `room.displayname` is favor of `room.getLocalizedDisplayname()`.
For migration you can just replace it everywhere. It will use the
MatrixDefaultLocalizations if you don't set one.

- Fix the timing error when the candidate arrives before the answer sdp. (Duan Weiwei)
- chore: use proper matchers in integration tests (Nicolas Werner)
- fix: Last message set incorrectly on all session key received (Krille)
- fix: play ringtone for incoming calls before trying to getUserMedia (td)
- fix: propogate filter to getParticipants in requestParticipants (td)
- refactor: room displayname calculation (Krille)

## [0.15.11] - 27th Dec 2022

- fix: Fix the called party not sending screensharing correctly. (cloudwebrtc)
- test: Add test for dendrites invalid pushrules (Nicolas Werner)
- test: Add tests for account data store and retrieve (Nicolas Werner)

## [0.15.10] - 23rd Dec 2022

- fix: make some Room getters null safe (TheOneWithTheBraid)
- fix: Store decrypted last event in store (Krille Fear)

## [0.15.9] - 14th Dec 2022

- refactor: Key manager megolm handling to make key generation more efficient

## [0.15.8] - 12th Dec 2022

- fix: leaved direct chat name (Reza)
- chore: Add voip connection tester (td)

## [0.15.7] - 1st Dec 2022

- fix: await requestKey() in event search (Philipp Grieshofer)
- fix: Request session key for bad encrypted events before the text search is carried out (Philipp Grieshofer)

## [0.15.6] - 24th Nov 2022

- feat: migrate e2ee test to DinD (TheOneWithTheBraid)
- chore: Update readme with new database (Christian Pauly)
- feat: Check if a key is verified by any master key (Reza)

## [0.15.5] - 22nd Nov 2022

- fix: follow account kind in registration (TheOneWithTheBraid)

## [0.15.4] - 21st Nov 2022

- feat: support MSC 3935: cute events (TheOneWithTheBraid)
- fix: PowerLevel calculation regarding to spec (Krille Fear)

## [0.15.3] - 18th Nov 2022

- fix: handleMissedCalls on remote hangups before answer (td)

## [0.15.2] - 16th Nov 2022

- fix: recover from very unlikely key upload errors (Nicolas Werner)

## [0.15.1] - 14th Nov 2022

- chore: Follow up fix for request users in invite rooms (Christian Pauly)
- chore: Put all hard-coded timeout parameters into the Timeouts class. (cloudwebrtc)
- chore: upgrade webrtc_interface, remove WebRTCDelegate.cloneStream. (cloudwebrtc)
- fix: Do not request users in not joined rooms (Christian Pauly)
- fix: sdp negotiation issue on iOS, close #335. (cloudwebrtc)
- refactor: Add argument for custom CreateRoomPreset to startDirectChat method (Grieshofer Philipp)
- refactor: Get rid of unnecessary type cast (Christian Pauly)
- refactor: Improve error handling for no olm session found exception (Christian Pauly)

## [0.15.0] - 28th Oct 2022

- chore: reduce error logging level of groupCall is null (td)
- fix: filter list for adding p2p call events (td)
- refactor: Remove deprecated fluffybox (Christian Pauly)
- chore: Lower logs level of native implementation noSuchMethod (Christian Pauly)
- fix: Redact originalSource on redaction (Christian Pauly)
- fix: Do not try to decrypt redacted events (Christian Pauly)

## [0.14.4] - 26th Oct 2022

- fix: Do not wait for first sync after migration init

## [0.14.3] - 24th Oct 2022

- fix: Do not assume that push rules are never malformed in account data
- chore: change codeowners
- refactor: Remove unused imports

## [0.14.2] - 18th Oct 2022

- Improve ice connection speed. (Duan Weiwei)
- chore: fix exception test after api_lite update (Nicolas Werner)
- feat: Add getter for own unverified devices (Christian Pauly)
- feat: Support evaluating pushrules (Nicolas Werner)
- feat: implement expire_ts in group calls and provide methods to terminate stale calls (td)
- fix: files get needlessly lowercased (Nicolas Werner)
- refactor: Use DateTime method instead of comparing milliseconds (Christian Pauly)

## [0.14.1] - 20th Sep 2022

- chore: Fire events by default during hangup. (cloudwebrtc)
- chore: Properly close usermedia/screen stream for 1v1/group calls. (cloudwebrtc)
- chore: fix analyzer error. (cloudwebrtc)
- chore: update. (cloudwebrtc)
- chore: update. (cloudwebrtc)
- feat: Add onSecretStored StreamController to SSSS (Christian Pauly)
- feat: Store original event (Christian Pauly)
- fix: Ensures that p2p/group calls are in progress to reject new call invitations, and emits a call reject events. (cloudwebrtc)
- fix: Fix remote hangup call causing local screenstream to be released. (cloudwebrtc)
- fix: don't assume redacts attribute from content to be valid (henri2h)
- refactor: Clean up deprecated website data (Christian Pauly)

## [0.14.0] - 12th Sep 2022

- chore: fix video muted updates for local stream (td)
- fix: Check ahead of download if a file exceeds the maximum file size (Nicolas Werner)
- fix: Get push rules crashes if malformed (Christian Pauly)
- fix: The initial sync waiting for a long time in some cases (Nicolas Werner)
- fix: properly handle events not already in the db (Nicolas Werner)
- fix: release renderer to fix crashes on android. (cloudwebrtc)
- fix: timeout when sending large files (Nicolas Werner)
- refactor: Avoid using private types in public api (Christian Pauly)
- refactor: Remove databaseDestroyer (Christian Pauly)

## [0.13.0] - 29th Aug 2022

- feat: Allow auto request keys via key sharing requests (Christian Pauly)
- feat: support dehydrated devices (Nicolas Werner)
- fix: Decrypt of last event might make an old message as last event (Christian Pauly)
- fix: Fixed issue with group calls for web and flutter. (cloudwebrtc)
- chore: Upgrade Hive to 2.2.3 which as a breaking change with BoxCollections (might need migration!!)

## [0.12.2] - 17th Aug 2022

- chore: Correctly release the cloned stream. (cloudwebrtc)
- fix: setRemoteDescription before adding local stream to prevent early feedsChanged and negotiation (td)

## [0.12.1] - 17th Aug 2022

- chore: simplify getTimeline condition a bit (Nicolas Werner)
- chore: support MIME in file factory (Lanna Michalke)
- fix: follow up for native implementations web (Lanna Michalke)

## [0.12.0] - 16th Aug 2022

- feat: Add markasdm and markasgroup commands (Christian Pauly)
- refactor: Add reference to itself in bootstrap onUpdate callback (Christian Pauly)

## [0.11.2] - 12th Aug 2022

- chore: Use onRoomState to monitor group call creation and member join and leave. (cloudwebrtc)
- chore: expose option to retry computations (Lanna Michalke)
- chore: fix group call id mismatch. (cloudwebrtc)
- feat: add coverage to MRs (Nicolas Werner)
- fix: Fix currentCID is null when handleNewCall is triggered, which will cause family-app. (cloudwebrtc)

## [0.11.1] - 1st Aug 2022

- chore: introduce native implementations (Lanna Michalke)
- fix: check for m.call permissions in groupCallEnabled (td)
- fix: make Hive Collection path nullable (Lanna Michalke)
- fix: missing null check (Lanna Michalke)

## [0.11.0] - 21th Jul 2022

- feat: Add powerLevelContentOverride to startDirectChat and createGroupChat (Isabella Hundstorfer)
- chore: add tests for group calls (td)
- chore: cleanup unused imports and analyzer warnings (td)
- feat: allow enabling group calls in already created rooms (td)
- feat: (breaking) keep timeline history for archive rooms in memory (Henri Carnot)
- fix: (potentially) a race in the archive test (Nicolas Werner)
- fix: Await unawaited stuff in voip code (Nicolas Werner)
- fix: race conditions in the SDK and its tests (Nicolas Werner)
- fix: set fixed time for ringer (td)
- refactor: Use import sorter and ci templates (Christian Pauly)

## [0.10.5] - 11th Jul 2022

- fix: Cache user profile even with cache=false when there is a cache

## [0.10.4] - 11th Jul 2022

- refactor: Better fetch own profile (Christian Pauly)

## [0.10.3] - 09th Jul 2022

- feat: Calc encryption health state and allow key sharing with unknown devices (Christian Pauly)
- fix: Add WebRTCDelegate.cloneStream to adapt to platform differences. (cloudwebrtc)
- fix: Database did not get cleared correctly (Christian Pauly)
- fix: fixed camera is still active after leaving the group call. (cloudwebrtc)
- fix: request history (Henri Carnot)
- refactor: Handle Ephemerals method (Christian Pauly)

## [0.10.2] - 17th Jun 2022

- feat: Implement CachedStreamController (Christian Pauly)
- fix: Only trigger onCall streams by latest call event for a call_id (Christian Pauly)
- fix: Support for OpenSSL 3.0 (Nicolas Werner)
- fix: implement sending queue (Reza)
- refactor: Call handleEphemerals with BasicRoomEvent instead of dynamic (Christian Pauly)
- refactor: Let \_handleRoomEvents use BasicEvent (Christian Pauly)
- refactor: Pass BasicEvent to handleEvent instead of JSON (Christian Pauly)
- refactor: Use handleRoomEvents method instead of handleEvent (Christian Pauly)
- refactor: Use tryGet in handleRoomEvents (Christian Pauly)

## [0.10.1] - 16th Jun 2022

- fix: ringtone not stopping when rejecting a call
- fix: missing turn servers in group calls

## [0.10.0] - 14th Jun 2022

- fix: BoxCollection not re-assignable (Lanna Michalke)
- feat: Support group calls (experimental) (cloudwebrtc)

## [0.9.12] - 9th Jun 2022

- refactor: add calcLocalizedBodyFallback method (Christian Pauly)

## [0.9.11] - 8th Jun 2022

- chore: Update Matrix API Lite for spaces fixes
- refactor: Rename methods and get rid of all Future getter
- fix: Do not show seen events in push notification

## [0.9.10] - 7th Jun 2022

- feat: Allow overriding supportedVersions (Christian Pauly)

## [0.9.9] - 2nd Jun 2022

- fix: Added deprecation mention for getUserByMXIDSync.

## [0.9.8] - 2nd Jun 2022

- feat: Add search for events in timeline (Krille Fear)
- feat: Add waitForSync helper (Henri Carnot)
- feat: Allow setting image size when generating a thumbnail (Henri Carnot)
- refactr: Make event.sender async (Henri Carnot)

## [0.9.7] - 23rd May 2022

- ci: use flutter images to install less (Nicolas Werner)
- feat: implement session export (Lanna Michalke)
- feat: support HiveCollections as Database provider (Lanna Michalke)
- fix: buggy e2e test (Lanna Michalke)
- fix: delete reaction (Reza)
- refactor: Migrate to Matrix Api Lite 1.0.0 (Krille Fear)

## [0.9.6] - 16th May 2022

- fix: Ignore invalid entries in `io.element.recent_emoji`

## [0.9.5] - 13th May 2022

- fix: Fix deep copy issue in the fragmented timeline feature and restored it

## [0.9.4] - 12th May 2022

- fix: Revert fragmented timeline feature temporarily to fix SENDING timeline

## [0.9.3] - 11th May 2022

- fix: Missing null check in get single room method

## [0.9.2] - 10th May 2022

- chore: Make path configurable in uiaLogin

## [0.9.1] - 9th May 2022

- feat: Store timestamp in the presence events
- chore: Move auth object passing to external msc implementations

## [0.9.0] - 4th May 2022

- refactor: Get rid of dynamic input in checkHomeserver (Christian Pauly)
- feat: Make image size editable (Henri Carnot)
- refactor: Remove old deprecations (Christian Pauly)
- feat: Get fully read marker (Henri Carnot)
- feat: Get the recent emoji according to `io.element.recent_emoji` (TheOneWithTheBraid)
- feat: Load fragmented timeline in memory (Henri Carnot)

## [0.8.20] - 14th Apr 2022

- fix: Wait for keys in push helper

## [0.8.19] - 14th Apr 2022

- feat: Get event from push notification
- feat: Add more localization strings and add default matrix localizations
- fix: Ignore no permission errors on requesting users

## [0.8.18] - 8th Apr 2022

- feat: check thumbnail size
- feat: fallback to thumbnail preview
- fix: Retry sending a file event

## [0.8.17] - 4th Apr 2022

- chore: Allow custom image resizer to be an async method

## [0.8.16] - 3th Apr 2022

- fix: Missing type check in power level calculation
- fix: Post load all users on room opening
- fix: Better fallback message for member events without any change
- fix: Store sending files in database and fix retrying to send them

## [0.8.15] - 30th Mar 2022

- feat: Pass through a custom image resize function to the client
- feat: Display dummy event in timeline for sending files
- chore: Move the call methods in room to the voip class.
- fix: properly create the directory for the pub credentials

## [0.8.14] - 25th Mar 2022

- feat: added doc (Henri Carnot)
- feat: add some more tests (Henri Carnot)
- feat: allow removing markdown formating (Henri Carnot)
- feat: Get event in a room faster by searching in database (Christian Pauly)
- feat: implement mofifying widgets (TheOneWithTheBraid)
- feat: Set loglevel in client constructor (Christian Pauly)
- fix: example (Henri Carnot)
- fix: remove pending outbound group session creation on completed or errored (Henri Carnot)
- fix: room members loading States were used before being fetched from the database. Thus, room membership states weren't set, and so, user display names weren't be fetched from the database. (Henri Carnot)
- refactor: Simplify relates to and make it more type safe (Christian Pauly)

## [0.8.13] - 02nd Mar 2022

- fix: send oldusername in displayname changed event
- fix: Dont encrypt reactions
- refactor: Make MatrixFile final and move all image calculation into isolate
- fix: own profile containing mxid
- chore: Update fluffybox

## [0.8.12] - 02nd Mar 2022

- fix: Rooms sort order after login
- fix: Change password using email authentication

## [0.8.11] - 19nd Feb 2022

- fix: Change password using email authentication

## [0.8.10] - 19nd Feb 2022

- chore: Increase default thumbnail size to 800
- fix: sortRooms should be triggered right before onSync is called
- fix: UIA request stucks forever on unexpected matrixExceptions

## [0.8.9] - 16nd Feb 2022

- feat: Return homeserver summary on checkHomeserver
- fix: hasNewMessage true when last event is sent
- fix: Correctly end the call.

## [0.8.8] - 15nd Feb 2022

- fix: Has new messages compares ts
- fix: handle dynamic content for pinned events

## [0.8.7] - 14nd Feb 2022

- fix: Show reactions as last events and refactor hasNewMessage

## [0.8.6] - 14nd Feb 2022

- feat: Add hasNewMessages flag to room
- fix: Sort rooms after updating the UI on web

## [0.8.5] - 14nd Feb 2022

- fix: exception on removed widgets
- fix: Fix black screen when end screensharing with system buttons.

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
- fix(ssss): Strip all whitespace characters from recovery keys upon decode Previously we stripped all spaces off of the recovery when decoding it, so that we could format the recovery key nicely. It turns out, however, that some element flavours also format with linebreaks, leading to the user having to manually remove them. We fix this by just stripping _all_ whitespace off of the recovery key. (Sorunome)

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
- feat: use m.new_content in lastEvent (so no more \* fallback)

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
