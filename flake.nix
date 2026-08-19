# SPDX-FileCopyrightText: 2019-Present Famedly GmbH
#
# SPDX-License-Identifier: AGPL-3.0-or-later
{
  description = "Matrix Dart SDK";

  inputs = {
    famedly-engineering-standards.url = "github:famedly/engineering-standards";

    nixpkgs.follows = "famedly-engineering-standards/nixpkgs";
    flake-parts.follows = "famedly-engineering-standards/flake-parts";
  };

  outputs =
    { famedly-engineering-standards, flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ famedly-engineering-standards.flakeModules.default ];

      systems = famedly-engineering-standards.lib.famedlySystems;

      perSystem = { config, ... }: {
        devShells.default = config.devShells.standards;

        famedly.standards = {
          dart.projects."." = {
            linting = {
              exclude = [
                "example/**"
                "lib/matrix_api_lite/generated/**"
              ];

              dartCodeLinter = {
                enable = true;

                # TODO: Enable these lints one after another and fix them.
                disabledRules = [
                  "avoid-late-keyword"
                  "avoid-redundant-async"
                  "member-ordering"
                  "prefer-match-file-name"
                  "avoid-dynamic"
                  "avoid-global-state"
                  "avoid-unrelated-type-assertions"
                  "avoid-unnecessary-type-casts"
                  "prefer-first"
                  "prefer-enums-by-name"
                  "prefer-immediate-return"
                ];
              };
            };
          };
        };
      };
    };
}
