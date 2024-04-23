#!/bin/bash

thread_count=$(getconf _NPROCESSORS_ONLN)

if [ -n "$NO_OLM" ]; then
    tagFlag="-x olm"
fi

dart test --concurrency=$thread_count --coverage=coverage_dir $tagFlag
TEST_CODE=$?

# lets you do more stuff like reporton
dart pub global activate coverage
dart pub global run coverage:format_coverage --lcov -i coverage_dir -o coverage_dir/lcov.info --report-on=lib/
dart pub global activate remove_from_coverage
dart pub global run remove_from_coverage:remove_from_coverage -f coverage_dir/lcov.info -r '\.g\.dart$'

exit $TEST_CODE