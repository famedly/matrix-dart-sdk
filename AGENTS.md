<!--
SPDX-FileCopyrightText: 2019-Present Famedly GmbH

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# AGENTS.md

## Pull request & commit conventions

- Use [Conventional Commits](https://www.conventionalcommits.org/) for every commit and PR title.
- Squash related commits together so the history stays clean (one logical change per commit).
- Keep code comments concise and developer-style — explain intent, not the obvious.
- Keep PR descriptions short and clean — a brief summary plus key verification, not exhaustive detail.
- Commits must always be signed, authored and committed solely by `cursoragent@cursor.com`, with no `Co-authored-by` trailer (bypass the Cursor co-author hook with `git commit --no-verify`).

## Cursor Cloud specific instructions

This repo is the **Matrix Dart SDK** — a pure-Dart library (not a Flutter app). The
"application" is the test suite plus the SDK's public API. The `example/` folder is a
small standalone Flutter app (single source file `example/lib/main.dart`) that depends
on the SDK via a path dependency; it needs the Flutter SDK to analyze/build and is
therefore excluded from the root `dart analyze` and linted/built separately by the
`example_analyze` and `example_build_web` jobs in `.github/workflows/integrate.yml`.
Flutter is **not** installed on this VM, so the example cannot be analyzed/built here.

Because pub auto-resolves the `example/` folder, a plain `dart pub get` at the repo
root fails (the example needs the Flutter SDK). Use `dart pub get --no-example` (or
`flutter pub get`, which the shared `dart` CI template uses). All plain-dart CI jobs
in `.github/workflows/integrate.yml` pass `--no-example`.

The Dart SDK version is pinned by `dart_version` in `.github/workflows/versions.env`
(currently 3.12.2), which is what CI feeds to `dart-lang/setup-dart`. Environment setup
installs exactly that version into `/usr/local/lib/dart-sdk` (symlinked as
`/usr/local/bin/dart`), so the VM follows the pin whenever it moves. An SDK older than
the pin cannot resolve dependencies: the `sqflite_common_ffi` dev dependency tracks new
SDKs aggressively, so `dart pub get` then dies with `version solving failed`. To switch
by hand, unpack
`https://storage.googleapis.com/dart-archive/channels/stable/release/<dart_version>/sdk/dartsdk-linux-x64-release.zip`
over `/usr/local/lib/dart-sdk`.

Other toolchain provided by the VM snapshot (do not reinstall): the Rust toolchain via
`rustup` (`CARGO_HOME=/usr/local/cargo`, `RUSTUP_HOME=/usr/local/rustup`, default
toolchain `stable`), Docker, mikefarah `yq` (at `/usr/local/bin/yq` — required by
`scripts/prepare_vodozemac.sh`; note the distro's `/usr/bin/yq` is the incompatible
python `yq`), and `libsqlite3-dev`/`lcov`. Environment setup fetches dependencies with
`dart pub get --no-example` (plain `dart pub get` fails on the Flutter example, see
above) and refreshes the toolchain with `rustup update stable`, because the
`dart-vodozemac` crates need a recent Rust (edition 2024, so >= 1.85).

If `dart pub get` ever fails with `fatal: hardlink different from source`, the
snapshot's `~/.pub-cache/git` mirror of the `famedly_dart_lints` git dependency is
stale: pub clones the mirror with hardlinks, which the VM's overlay filesystem cannot
satisfy for files from a lower layer. Run `rm -rf ~/.pub-cache/git` and retry; pub
re-fetches the mirror (~1 MB).

### Lint / analyze
- `dart analyze` (clean on the pinned SDK: "No issues found!"). `dart format --output=none --set-exit-if-changed lib` enforces formatting in CI.
- License headers: `~/.local/bin/reuse lint`, the local equivalent of the `reuse-compliance-check` CI job. Every new file needs the SPDX header the other files carry, or an entry in `REUSE.toml`.

### Tests
- Non-E2EE only: `NO_OLM=1 ./scripts/test.sh` (skips `olm`-tagged tests, no vodozemac needed).
- Full suite incl. E2EE: `./scripts/test.sh` (runs all 52 files sequentially, ~10 min). Requires the native vodozemac library at `./rust/target/debug/libvodozemac_bindings_dart.so`.
- Single file: `dart test test/<name>_test.dart` (add `-x olm` to skip encryption tests).
- vodozemac native lib: built by `./scripts/prepare_vodozemac.sh` (git-clones `dart-vodozemac` into `./rust/` and runs `cargo build`, ~15 s). Environment setup runs it, so the `.so` is normally present. Each environment build re-clones `/workspace`, which wipes the gitignored `./rust/` dir, so re-run the script whenever `./rust/target/debug/libvodozemac_bindings_dart.so` is missing or the `vodozemac` version in `pubspec.yaml` changes.

### Integration / E2EE tests against a real homeserver
- Needs a running homeserver. `dockerd` is installed but is NOT auto-started — start it first (e.g. `sudo dockerd &`) and confirm with `sudo docker info`. The daemon is configured for `fuse-overlayfs` with the containerd-snapshotter disabled (required for Docker on this VM).
- Start a homeserver and create users: `scripts/integration-server-conduit.sh` (also `-synapse`/`-dendrite`), then `export HOMESERVER=localhost:80 HOMESERVER_IMPLEMENTATION=conduit`, `source scripts/integration-create-environment-variables.sh`, and `scripts/integration-prepare-homeserver.sh`.
- Run: `dart --define=HOMESERVER=$HOMESERVER --define=USER1_NAME=$USER1_NAME --define=USER1_PW=$USER1_PW --define=USER2_NAME=$USER2_NAME --define=USER2_PW=$USER2_PW --define=USER3_NAME=$USER3_NAME --define=USER3_PW=$USER3_PW test test_driver/matrixsdk_test.dart -p vm`.
- Caveat: the full `E2EE` integration test only fully passes against **synapse** (the primary supported server). Against **conduit**/**dendrite** some deep multi-device olm-session assertions are expected to fail (CI runs these with `fail-fast: false`); login, room creation and encrypted message round-trips still work.

### Web targets (optional, need Chrome)
- `dart_web_compatible` builds `web_test` via `dart run webdev build`; `database_web_tests` runs `dart test test/box_test.dart --platform chrome`. Chrome is not installed by the update script — install it if you need these.
