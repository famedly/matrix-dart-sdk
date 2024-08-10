# Matrix SDK

Matrix (matrix.org) SDK written in dart.

## Native libraries

For E2EE, libolm must be provided.

Additionally, OpenSSL (libcrypto) must be provided on native platforms for E2EE.

For flutter apps you can easily import it with the [flutter_olm](https://pub.dev/packages/flutter_olm) and the [flutter_openssl_crypto](https://pub.dev/packages/flutter_openssl_crypto) packages.

```sh
flutter pub add matrix
flutter pub add flutter_olm
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
