## [1.7.2] - 4th Oct 2023

- chore: add general and publish ci (td)
- chore: Add adjusted issue templates from product-management (Malin Errenst)
- chore: make dependencies compatible with dart 3 (Nicolas Werner)
- chore: add github action (Niklas Zender)

## [1.7.1] - 22nd Jun 2023

- fix: Fixed fake_matrix_api.dart signedOneTimeKeys upload (Malin Errenst)
- fix: Fix type cast to fix test in matrix-fhir-dart-sdk (Malin Errenst)

## [1.7.0] - 12th Jun 2023

Breaking Change: 
Refactoring from Map<String, dynamic> to Map<String, Object?> makes some 
type casts neccessary

- chore: add qr releated eventTypes (td)
- refactor: Get rid of dynamic lists (Krille)
- chore: bump version (Malin Errenst)
- docs: Add regenerate code instructions to readme (Krille)
- chore: Remove tags for CI test stage (Malin Errenst)
- refactor: Changed Map<String, dynamic> to Map<String, Object?> (Malin Errenst)
- chore: generated folder from recent dart_openapi_codegen (Malin Errenst)
- chore: sort imports (Nicolas Werner)
- ci: Use the ci template (Nicolas Werner)

## [1.6.1] - 17th Apr 2023

Fixes a small issue in the last release, where some enhanced enums were not
updated and as such missing a few members.

- fix: Update the generated enum files

## [1.6.0] - 17th Apr 2023

This release updates to version 1.6 of the Matrix specification. Users might
need to update their read receipt calls to the API changes.

- feat: Upgrade to spec 1.6

## [1.1.10] - 27th Jan 2023

- chore: Update enhanced_enum to 0.2.4

## [1.1.9] - 7th Nov 2022

- feat: Allow converting of stacktraces in logs

## [1.1.8] - 29th Aug 2022

- fix: Edge case where MatrixException.error differs from errcode
- chore: add pushrules to the event types

## [1.1.7] - 29th Aug 2022

- fix: Parsing of MatrixException parameters

## [1.1.6] - 26th Aug 2022

- fix: Fixed missing .pub-cache folder creation in .gitlab-ci.yml

## [1.1.5] - 25th Aug 2022

- fix: Fixed dysfunctional key-verification (Emoji+manual)

## [1.1.4] - 25th Aug 2022

- Revert "fix: Secret storage keys are used as account data but are not uri encoded"
- chore: disable dynamic calls (Nicolas Werner)
- chore: export filter map extension (Nicolas Werner)
- chore: strict casts (Nicolas Werner)
- chore: strict inference (Nicolas Werner)
- chore: strict raw types (Nicolas Werner)
- chore: upgrade from pedantic to lints (Nicolas Werner)

## [1.1.3] - 2nd Aug 2022

- fix: Secret storage keys are used as account data but are not uri encoded
- chore: export filter map extension

## [1.1.2] - 2nd Aug 2022

- feat: Add a flag to disable colors in logs

## 1.1.1

- fix: wrong type for children_state in spaces hierarchy API
- fix: Missing trailing slash on pushrules endpoint
- tests: added tests for spaces hierarchy

## 1.1.0

- fix: wrong types in spaces hierarchy API
- fix: Add missing versions to fake matrix api
- feat: Authenticate media downloads

## 1.0.0

This release should be compatible with version 1.2 of the Matrix specification.

- feat: Migrate to Matrix v1.2 spec
- feat: Add GroupCallPrefix/GroupCallMemberPrefix to EventTypes.

## 0.5.3

- chore: Add missing matrix error types as per spec
- feat: add additionalProperties in PusherData
- feat: deletePusher

## 0.5.2

- feat: Colored logs on native and web
- chore: Make some tryGet errors verbose and display line

## 0.5.1

- feat: Add constructors to SyncUpdate classes

## 0.5.0

- fix: threepidCreds should be threepid_creds and an object

## 0.4.4

- chore: workaround for invalid getTurnServer responses from synapse

## 0.4.3

- fix: Make type in AuthenticationData nullable
- refactor: remove uploadKeySignatures (use uploadCrossSigningSignatures)

## 0.4.2

- feat: Add more call event for improve voip.

## 0.4.1

- fix: change tryGet default loglevel to Optional

## 0.4.0

- refactor: Migrate to null safety
- refactor: Use openAPI code generation to create most of the methods
- refactor: remove timeouts in matrix_api_lite

## 0.3.5

- feat: Add image pack event content models

## 0.3.3

- fix: Log filter in wrong direction

## 0.3.2

- fix: Logs should only printed if loglevel is high enough

## 0.3.1

- change: Remove logger package

## 0.3.0

- feat: operation names from OpenAPI spec

## 0.2.6

- fix: Missing RoomCreationTypes

## 0.2.5

- fix: Request aliases

## 0.2.3

- feat: Add room and event types for spaces

## 0.2.2

- chore: upgrade logger to 1.0.0
- refactor: upgrade to http 0.13

## 0.2.1

- fix: Update dependency mime

## 0.2.0

- refactor: login method AuthenticationIdentifier

This is a breaking change for the login method to use the correct format.
It makes it possible to login with email or phone.
Also this does some housekeeping stuff while
upgrading to pedantic 1.11.0 which doesnt
allow curly braces in Strings where not needed
anymore.

## 0.1.9

- feat: Add support for fallback keys

## 0.1.8

- fix: Wrong parameters use

## 0.1.7

- change: Less noisy one-line logs

## 0.1.6

- fix: well-known in fake_matrix_api

## 0.1.5

- Add m.dummy event
- fix: Deep-copy arrays correctly

## 0.1.4

- Fix creating shallow copies all the time

## 0.1.3

- Set Content-Length on upload

## 0.1.2

- Add more encryption and decryption content parsing

## 0.1.1

- Add RoomEncryptedContent and RoomEncryptionContent

## 0.1.0

- Initial version
