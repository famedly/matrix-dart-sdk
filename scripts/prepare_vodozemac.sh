#!/usr/bin/env bash

git clone https://github.com/famedly/dart-vodozemac.git
mv ./dart-vodozemac/rust ./
rm -rf dart-vodozemac
cd ./rust
cargo build
cd ..