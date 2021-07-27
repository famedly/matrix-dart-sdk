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
