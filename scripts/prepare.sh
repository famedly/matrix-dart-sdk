#!/usr/bin/env bash

if which flutter >/dev/null; then
  flutter pub get
else
  dart pub get
fi
