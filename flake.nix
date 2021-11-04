{
  description = "Visual Studio Code Server support in NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      name = "vscode-server";
      lib = import (nixpkgs + "/lib");

      # Recursively merge a list of attribute sets. Following elements take
      # precedence over previous elements if they have conflicting keys.
      recursiveMerge = with lib; foldl recursiveUpdate { };

      eachDevelopSystem = flake-utils.lib.eachDefaultSystem;
      eachTargetSystem = flake-utils.lib.eachSystem (lib.filter (lib.hasSuffix "-linux") flake-utils.lib.defaultSystems);
    in
    recursiveMerge [
      #
      # COMMON OUTPUTS FOR ALL DEVELOPMENT SYSTEMS
      #
      (eachDevelopSystem (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          # nix `check`
          checks.nixpkgs-fmt = pkgs.runCommand "check-nix-format" { } ''
            ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check ${./.}
            mkdir $out #sucess
          '';

          # `nix develop`
          devShell = pkgs.mkShell {
            name = "${name}-dev-shell";
            buildInputs = with pkgs; [ nixpkgs-fmt ];
          };
        })
      )
      #
      # CHECKS SPECIFIC TO LINUX SYSTEMS
      #
      (eachTargetSystem (system: {
        # TODO: Add a test for the module
      })
      )
      #
      # SYSTEM-INDEPENDENT OUTPUTS
      #
      {
        nixosModules."${name}-nixos" = import ./modules/vscode-server;
        nixosModules."${name}-home" = import ./modules/vscode-server/home.nix;
      }
    ];
}
