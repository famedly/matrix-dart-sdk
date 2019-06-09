#!/usr/bin/env bash
if [ -d test ]
then
    if [ -z "$(ls -A test)" ]; then
       exit 0
    else
       flutter test --coverage
    fi
else
    exit 0
fi
