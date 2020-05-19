#!/bin/sh -e
pub run test -p vm
pub run test_coverage
genhtml -o coverage coverage/lcov.info || true