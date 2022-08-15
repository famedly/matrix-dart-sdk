#!/bin/bash
if which flutter >/dev/null; then
    flutter pub global activate junitreport
    flutter test --coverage --machine | tee TEST-report.json
    TEST_CODE=${PIPESTATUS[0]}
    
    # junit report
    flutter pub global run junitreport:tojunit --input TEST-report.json --output TEST-report.xml
    # remove shell escapes since those are invalid xml
    sed 's/&#x1B;//g' -i TEST-report.xml
    
    # coverage
    flutter pub global activate remove_from_coverage
    flutter pub global run remove_from_coverage:remove_from_coverage -f coverage/lcov.info -r '\.g\.dart$'
else
    dart pub global activate junitreport
    # Test coverage using dart only is broken: https://github.com/dart-lang/test/issues/1698
    #dart test --coverage=coverage --file-reporter='json:TEST-report.json'
    dart test --file-reporter='json:TEST-report.json'
    TEST_CODE=$?
    
    # junit report
    dart pub global run junitreport:tojunit --input TEST-report.json --output TEST-report.xml
    # remove shell escapes since those are invalid xml
    sed 's/&#x1B;//g' -i TEST-report.xml
    
    # coverage -> broken see https://github.com/dart-lang/test/issues/1698
    #dart pub global activate coverage

    #reporton="--report-on=lib/"
    #if [ -n "$NO_OLM" ]; then reporton="--report-on=lib/src --report-on=lib/msc_extensions"; fi

    #dart pub global run coverage:format_coverage -i coverage/  --lcov -o coverage/lcov.info $reporton
    #dart pub global activate remove_from_coverage
    #dart pub global run remove_from_coverage:remove_from_coverage -f coverage/lcov.info -r '\.g\.dart$'
fi

# coverage html report
genhtml -o coverage coverage/lcov.info || true

# https://github.com/eriwen/lcov-to-cobertura-xml
lcov_cobertura.py coverage/lcov.info || true

exit $TEST_CODE
