# Matrix SDK

Matrix (matrix.org) SDK written in dart.

## Native libraries

For E2EE, vodozemac must be provided.

For flutter apps you can easily import it with the [flutter_vodozemac](https://pub.dev/packages/flutter_vodozemac) package.

```sh
flutter pub add matrix

# Optional: For end to end encryption:
flutter pub add flutter_vodozemac
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

dump
```
/Users/techno_disaster/Projects/Famedly/flutter_rust_bridge/target/debug/flutter_rust_bridge_codegen generate && /Users/techno_disaster/Projects/Famedly/flutter_rust_bridge/target/debug/flutter_rust_bridge_codegen build-web --dart-root "./" --rust-root "../matrix-mls-client" --wasm-bindgen-args="--no-modules-global=mls_wasm_bindgen" && rm ../call/web/matrix_mls_client* && cp web/pkg/matrix_mls_client* ../call/web/
```