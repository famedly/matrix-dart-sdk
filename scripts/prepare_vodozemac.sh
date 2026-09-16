#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2019-Present Famedly GmbH
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Fail loudly: without this the script used to exit 0 on a broken `cargo build`,
# so the missing native library only surfaced much later as cryptic failures in
# the olm-tagged tests.
set -euo pipefail

version=$(yq ".dependencies.vodozemac" < pubspec.yaml)
version=${version#^}
if [ -z "$version" ] || [ "$version" = "null" ]; then
  echo "prepare_vodozemac: no dependencies.vodozemac version in pubspec.yaml" >&2
  exit 1
fi

rm -rf rust dart-vodozemac
git clone https://github.com/famedly/dart-vodozemac.git -b "$version"
mv ./dart-vodozemac/rust ./
rm -rf dart-vodozemac
cd ./rust
cargo build
cd ..
