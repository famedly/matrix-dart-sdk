#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2019-Present Famedly GmbH
#
# SPDX-License-Identifier: AGPL-3.0-or-later

rm -rf rust
version=$(yq ".dependencies.vodozemac" < pubspec.yaml)
version=$(expr "$version" : '\^*\(.*\)')
git clone https://github.com/famedly/dart-vodozemac.git -b ${version}
mv ./dart-vodozemac/rust ./
rm -rf dart-vodozemac
cd ./rust
cargo build
cd ..