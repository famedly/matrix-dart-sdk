#!/bin/sh -e
if which flutter >/dev/null; then
    flutter --no-version-check test test_driver/matrixsdk_test.dart --dart-define=HOMESERVER=$HOMESERVER --dart-define=USER1_NAME=$USER1_NAME --dart-define=USER2_NAME=$USER2_NAME --dart-define=USER3_NAME=$USER3_NAME --dart-define=USER1_PW=$USER1_PW --dart-define=USER2_PW=$USER2_PW --dart-define=USER3_PW=$USER3_PW
else
    dart --define=HOMESERVER=$HOMESERVER --define=USER1_NAME=$USER1_NAME --define=USER2_NAME=$USER2_NAME --define=USER3_NAME=$USER3_NAME --define=USER1_PW=$USER1_PW --define=USER2_PW=$USER2_PW --define=USER3_PW=$USER3_PW test test_driver/matrixsdk_test.dart -p vm
fi
