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

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) asset=libvodozemac_bindings_dart-linux-x64.so ;;
  Linux-aarch64) asset=libvodozemac_bindings_dart-linux-arm64.so ;;
  Darwin-*) asset=libvodozemac_bindings_dart-macos.dylib ;;
  *) echo "prepare_vodozemac: no prebuilt vodozemac for $(uname -sm)" >&2; exit 1 ;;
esac

# The tests load it from ./rust/target/debug/ (see test/fake_client.dart).
rm -rf rust
mkdir -p rust/target/debug
base="https://github.com/famedly/dart-vodozemac/releases/download/v${version}"
dest="rust/target/debug/libvodozemac_bindings_dart.${asset##*.}"
sum=$(curl -fsSL "$base/SHA256SUMS" | awk -v f="$asset" '$2 == f { print $1 }')
curl -fsSL "$base/$asset" -o "$dest"
sha256=sha256sum; command -v sha256sum >/dev/null || sha256="shasum -a 256"
echo "$sum  $dest" | $sha256 -c -
