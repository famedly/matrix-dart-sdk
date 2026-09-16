<!--
SPDX-FileCopyrightText: 2019-Present Famedly GmbH

SPDX-License-Identifier: AGPL-3.0-or-later
-->

To enable end to end encryption you need to setup [Vodozemac](https://pub.dev/packages/vodozemac). For this you need Rust installed locally: [rust-lang.org/tools/install](https://www.rust-lang.org/tools/install)

For Flutter you can use [flutter_vodozemac](https://pub.dev/packages/flutter_vodozemac).

```sh
flutter pub add flutter_vodozemac
```

Now before you create your `Client`, init vodozemac:

```dart
import 'package:flutter_vodozemac/flutter_vodozemac' as vod;

// ...

await vod.init();

final client = Client(/*...*/);
```

This should work on Android, iOS, macOS, Linux and Windows.

For web you need to compile vodozemac to wasm. [Please refer to the Vodozemac bindings documentation](https://pub.dev/packages/vodozemac#build-for-web).

### Using Vodozemac with NativeImplementations

When using NativeImplementations you have to initialize Vodozemac there as well.
Just pass the same init function to it:

```dart
final client = Client('Matrix Client',
    // ...
    // ...
    nativeImplementations: NativeImplementationsIsolate(
        compute,
        vodozemacInit: () => vod.init(),
    ),
    // ...
);
```

### Setup your crypto identity

To use **Secure Storage and Sharing**, **Cross Signing** and the **Online Key Backup**,
you should set up your crypto identity. The crypto identity is defined as the
combined feature of those three features. First you should check if it is already
set up for this account:

```dart
final state = await client.getCryptoIdentityState();
if (state.initialized) {
    print('Your crypto identity is initialized. You can either restore or wipe it.');
}
if (state.connected) {
    print('Your crypto identity is initialized and you are connected. You can now only wipe it to reset your passphrase or recovery key!');
}
```

If `initialized` is `false` you need to initialize your crypto identity first:

```dart
final recoveryKey = await client.initCryptoIdentity();
```

You can also set a custom passphrase:

```dart
final recoveryKey = await client.initCryptoIdentity(
  passphrase: 'SuperSecurePassphrase154%',
);
```

`getCryptoIdentityState()` also reports `keyBackupEnabled` and
`crossSigningEnabled` independently. If `initialized` is `false` but the
account already holds part of an identity (missing key backup or
cross-signing, incomplete cross-signing keys, or a cancelled setup after
UIA), heal it in place by reusing the existing secret storage key — the
recovery key stays valid:

```dart
final ssss = client.encryption!.ssss;
final recoveryKey = await client.initCryptoIdentity(
  reuseExistingStorageRecoveryKeyOrPassphrase: passphraseOrRecoveryKey,
  wipeSecureStorage: false, // forced when reusing; shown for clarity
  wipeKeyBackup: false,
  wipeCrossSigning: false,
  setupMasterKey: !ssss.isSecret(EventTypes.CrossSigningMasterKey),
  setupSelfSigningKey: !ssss.isSecret(EventTypes.CrossSigningSelfSigning),
  setupUserSigningKey: !ssss.isSecret(EventTypes.CrossSigningUserSigning),
  setupOnlineKeyBackup: !ssss.isSecret(EventTypes.MegolmBackup),
);
```

Normal `initCryptoIdentity()` creates or rotates secret storage and returns
a new recovery key. With
`reuseExistingStorageRecoveryKeyOrPassphrase`, the existing key is opened
instead and the returned string is that key's recovery key. Optionally pass
`keyIdentifier` when several secret storage keys exist, and `selfSign`
(default `true`) to sign this device afterward.

If reuse throws `BootstrapBadStateException`, there is no usable secret
storage key or bootstrap would have to create a new one — fall back to
`initCryptoIdentity()` without the reuse parameter, which regenerates
everything and returns a new recovery key (a destructive operation).

To then reconnect on a new device you can restore your crypto identity:

```dart
await client.restoreCryptoIdentity(passphraseOrRecoveryKey);
```

If you have lost your passphrase or recovery key, you can wipe your crypto
identity and get a new key with `client.initCryptoIdentity()` at any time.

> [!TIP]
> An alternative to `client.restoreCryptoIdentity()` can be that you use
> **key verification** to connect with another session which is already connected.
>
> The Client would then request all necessary secrets of your crypto identity
> automatically via **to-device-messaging**.