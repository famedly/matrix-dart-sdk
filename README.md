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