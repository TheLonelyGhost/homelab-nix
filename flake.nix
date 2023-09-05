{
  description = "Home lab configurations for NixOS";

  inputs.nixpkgs.url = "flake:nixpkgs";
  inputs.flake-utils.url = "flake:flake-utils";
  inputs.flake-compat.url = "github:edolstra/flake-compat";
  inputs.flake-compat.flake = false;
  inputs.overlays.url = "github:thelonelyghost/blank-overlay-nix";

  outputs = { self, nixpkgs, flake-utils, flake-compat, overlays }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlays.overlays.default ];
          };
          fabio = import ./packages/fabio.nix {
            inherit pkgs;
          };
        in
        {
          devShells.default = pkgs.mkShell {
            nativeBuildInputs = [
              pkgs.bashInteractive
              pkgs.gnumake
              pkgs.statix
            ];
            buildInputs = [
            ];

            shellHook = ''
              export STATIX='${pkgs.statix}/bin/statix'
            '';
          };

          packages = {
            inherit fabio;

            default = fabio;
          };
        }
      ) // {
      nixosModules.default = import ./nixos/default.nix;
      nixosModules.seedbox = import ./nixos/seedbox;
      nixosModules.fabio = import ./nixos/fabio.nix;
      nixosModules.flood = import ./nixos/flood.nix;
    };
}
