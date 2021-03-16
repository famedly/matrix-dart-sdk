#!/bin/sh -e
# pub run test -p vm
flutter test --coverage
flutter pub global activate remove_from_coverage
flutter pub global run remove_from_coverage:remove_from_coverage -f coverage/lcov.info -r '\.g\.dart$'
genhtml -o coverage coverage/lcov.info || true
