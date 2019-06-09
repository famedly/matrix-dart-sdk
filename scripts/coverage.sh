#!/usr/bin/env bash
if [ -d "coverage" ]
then
  ls -A ./coverage
  if [ -z "$(ls -A ./coverage)" ]; then
    exit 0
  else
    if [ -f "coverage/lcov.info" ]
    then
      genhtml -o coverage coverage/lcov.info || exit 0
    else
      exit 0
    fi
  fi
else
  exit 0
fi