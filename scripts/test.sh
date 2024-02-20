#!/bin/bash

thread_count=$(getconf _NPROCESSORS_ONLN)

if which flutter >/dev/null; then
    flutter pub global activate junitreport
    # use default coverage dir
    flutter test --concurrency=$thread_count --coverage
    TEST_CODE=$?
    
    # coverage
    flutter pub global activate remove_from_coverage
    flutter pub global run remove_from_coverage:remove_from_coverage -f $1/lcov.info -r '\.g\.dart$'
    genhtml -o coverage coverage/lcov.info || true
else
    dart test --concurrency=$thread_count --coverage=$1
    TEST_CODE=$?
    
    # coverage -> broken see https://github.com/dart-lang/test/issues/1698
    dart pub global activate coverage

    #reporton="--report-on=lib/"
    if [ -n "$NO_OLM" ]; then reporton="--report-on=lib"; fi

    dart pub global run coverage:format_coverage --lcov -i $1 -o $1/lcov.info $reporton
    dart pub global activate remove_from_coverage
    dart pub global run remove_from_coverage:remove_from_coverage -f $1/lcov.info -r '\.g\.dart$'
    genhtml -o $1 $1/lcov.info || true
fi

# https://github.com/eriwen/lcov-to-cobertura-xml
# lcov_cobertura.py coverage/lcov.info || true

exit $TEST_CODE
