#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2019-Present Famedly GmbH
#
# SPDX-License-Identifier: AGPL-3.0-or-later

set -eo pipefail

# Build tag flag.
#
# NO_OLM=1 in the environment excludes vodozemac-dependent tests via the
# existing `tags: 'olm'` markers in the test files. Passed through to each
# per-file dart test invocation below.
tagFlag=""
if [ -n "${NO_OLM:-}" ]; then
    tagFlag="-x olm"
fi

# Final exit code: 0 if every file's `dart test` succeeded, non-zero otherwise.
# Cannot use `set -e` semantics here because we want the loop to keep going
# after a file fails so we can report _all_ failures, not just the first.
TEST_CODE=0
FAILED_FILES=()
SKIPPED_FILES=()

mkdir -p coverage_dir

# Collect test files, sorted for deterministic ordering across runs.
# Use `while read` instead of `mapfile` so this works on macOS bash 3 as well
# as Ubuntu bash 5.

# ONLY RUNS TESTS WHICH END WITH _test.dart
test_files=()
while IFS= read -r f; do
    test_files+=("$f")
done < <(find test -type f -name '*_test.dart' | sort)

total=${#test_files[@]}
echo "============================================================"
echo " Running $total test file(s) sequentially"
echo " NO_OLM=${NO_OLM:-unset}, tagFlag='${tagFlag}'"
echo "============================================================"

i=0
for test_file in "${test_files[@]}"; do
    i=$((i + 1))
    echo ""
    echo "------------------------------------------------------------"
    echo "[$i/$total] START $test_file"
    echo "------------------------------------------------------------"

    # `|| rc=$?` keeps the script alive even when a file fails. Without this
    # `set -e` would abort on first failure and skip the rest of the suite.
    rc=0
    dart test "$test_file" --coverage=coverage_dir $tagFlag || rc=$?

    # `dart test` exits 79 when tag selectors exclude every test in the file
    # (e.g. NO_OLM=1 against a file whose group is tagged 'olm'). Treat that
    # as a skip rather than a failure.
    if [ "$rc" -eq 0 ]; then
        echo "[$i/$total] PASS  $test_file"
    elif [ "$rc" -eq 79 ]; then
        echo "[$i/$total] SKIP  $test_file (excluded by tag filter)"
        SKIPPED_FILES+=("$test_file")
    else
        echo "[$i/$total] FAIL  $test_file (exit $rc)"
        FAILED_FILES+=("$test_file (exit $rc)")
        TEST_CODE=1
    fi
done

echo ""
echo "============================================================"
echo " Summary: $((total - ${#FAILED_FILES[@]} - ${#SKIPPED_FILES[@]}))/$total file(s) passed, ${#SKIPPED_FILES[@]} skipped, ${#FAILED_FILES[@]} failed"
echo "============================================================"
if [ ${#SKIPPED_FILES[@]} -gt 0 ]; then
    echo " Skipped files (excluded by tag filter):"
    for f in "${SKIPPED_FILES[@]}"; do
        echo "   - $f"
    done
    echo "============================================================"
fi
if [ ${#FAILED_FILES[@]} -gt 0 ]; then
    echo " Failed files:"
    for f in "${FAILED_FILES[@]}"; do
        echo "   - $f"
    done
    echo "============================================================"
fi

echo ""
echo "Generating coverage report..."
dart pub global activate coverage
dart pub global run coverage:format_coverage \
  --lcov \
  -i coverage_dir \
  -o coverage_dir/lcov.info \
  --report-on=lib/

dart pub global activate remove_from_coverage
dart pub global run remove_from_coverage:remove_from_coverage \
  -f coverage_dir/lcov.info \
  -r '\.g\.dart$'

echo ""
echo "Exiting with TEST_CODE=$TEST_CODE"
exit "$TEST_CODE"