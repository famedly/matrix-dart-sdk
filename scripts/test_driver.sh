#!/bin/sh -e
if which flutter >/dev/null; then
    flutter pub run test_driver/matrixsdk_test.dart -p vm
else
    dart pub run test_driver/matrixsdk_test.dart -p vm
fi
