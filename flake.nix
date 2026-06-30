{
  description = "Matrix Dart SDK";

  inputs = {
    famedly-engineering-standards.url = "github:famedly/engineering-standards/yg/dart-flutter-support";

    nixpkgs.follows = "famedly-engineering-standards/nixpkgs";
    flake-parts.follows = "famedly-engineering-standards/flake-parts";
  };

  outputs =
    { famedly-engineering-standards, flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ famedly-engineering-standards.flakeModules.default ];

      systems = famedly-engineering-standards.lib.famedlySystems;

      perSystem =
        { config, ... }:
        {
          devShells.default = config.devShells.dart;

          famedly.standards = {
            dart.projects."." = { };
          };
        };
    };
}
