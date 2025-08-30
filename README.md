# Matrix SDK

Matrix (matrix.org) SDK written in dart.

## Native libraries

For E2EE, vodozemac must be provided.

Additionally, OpenSSL (libcrypto) must be provided on native platforms for E2EE.

For flutter apps you can easily import it with the [flutter_vodozemac](https://pub.dev/packages/flutter_vodozemac) and the [flutter_openssl_crypto](https://pub.dev/packages/flutter_openssl_crypto) packages.

```sh
flutter pub add matrix

# Optional: For end to end encryption:
flutter pub add flutter_vodozemac
flutter pub add flutter_openssl_crypto
```

## Get started

See the API documentation for details:

[API documentation](https://pub.dev/documentation/matrix/latest/)

### Tests

```shell
thread_count=$(getconf _NPROCESSORS_ONLN) // or your favourite number :3
dart test --concurrency=$thread_count test
```

- Adding the `-x olm` flag will skip tests which require olm
- Using `-t olm` will run only olm specific tests, but these will probably break as they need prior setup (which is not marked as olm and hence won't be run)
