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
