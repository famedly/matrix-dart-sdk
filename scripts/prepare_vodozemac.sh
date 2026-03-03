#!/usr/bin/env bash

rm -rf rust
version=$(yq ".dependencies.vodozemac" < pubspec.yaml)
version=$(expr "$version" : '\^*\(.*\)')
git clone https://github.com/famedly/dart-vodozemac.git -b ${version}
mv ./dart-vodozemac/rust ./
rm -rf dart-vodozemac
cd ./rust
cargo build
cd ..