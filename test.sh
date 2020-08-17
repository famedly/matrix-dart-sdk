#!/bin/sh -e
# pub run test -p vm
pub run test_coverage --print-test-output
pub global activate remove_from_coverage
pub global run remove_from_coverage:remove_from_coverage -f coverage/lcov.info -r '\.g\.dart$'
genhtml -o coverage coverage/lcov.info || true
