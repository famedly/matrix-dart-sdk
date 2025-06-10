To enable end to end encryption you need to setup [Vodozemac](https://pub.dev/packages/vodozemac). For this you need Rust installed locally: [rust-lang.org/tools/install](https://www.rust-lang.org/tools/install)

For Flutter you can use [flutter_vodozemac](https://pub.dev/packages/flutter_vodozemac).

```sh
flutter pub add flutter_vodozemac
```

You also need [flutter_openssl_crypto](https://pub.dev/packages/flutter_openssl_crypto).

```sh
flutter pub add flutter_openssl_crypto
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