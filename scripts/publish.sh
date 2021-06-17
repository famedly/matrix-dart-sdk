#!/bin/sh -e
mv docs .docs
flutter pub publish --dry-run
flutter pub publish
mv .docs docs