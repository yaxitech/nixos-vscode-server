{
  description = "Visual Studio Code Server support in NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # QEMU 6.1.0 hangs when running NixOS tests on a virtualized host, e.g., a GitHub Action runner
    # Therefore, we use a NixOS Python test which still relies on QEMU 6.0.0.
    # Upstream issue: https://github.com/NixOS/nixpkgs/issues/141596
    nixpkgs-nixos-test.url = "github:nixos/nixpkgs/e1fc1a80a071c90ab65fb6eafae5520579163783";
    # Only required for NixOS tests
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-nixos-test, flake-utils, home-manager }:
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
      # CHECKS SPECIFIC TO TARGET SYSTEMS
      #
      (eachTargetSystem (system:
        let
          overlayQemu6_0_0 = final: prev: {
            qemu = (import nixpkgs-nixos-test { inherit (prev) system; }).qemu;
          };
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlayQemu6_0_0 ];
          };
          pythonTest = import (nixpkgs + "/nixos/lib/testing-python.nix") { inherit system pkgs; };

          systemdUnitPathSystem = "/etc/systemd/user/vscode-server-fixup.service";
          systemdUnitPathHome = "$HOME/.config/systemd/user/vscode-server-fixup.service";
        in
        {
          # Test for the NixOS module
          checks."${name}-nixos" = pythonTest.makeTest {
            name = "${name}-nixos";

            machine = {
              imports = [
                self.nixosModules.system
              ];

              services.vscode-server-fixup.enable = true;
            };

            testScript = ''
              machine.start()
              machine.wait_for_unit("default.target")

              with subtest("Installs the system-wide systemd user service"):
                machine.succeed("test -f ${systemdUnitPathSystem}")

              with subtest("Does not install the systemd user service in home"):
                machine.fail("test -f ${systemdUnitPathHome}")
            '';
          };

          # Test for the Home Manager module
          checks."${name}-home" = pythonTest.makeTest {
            name = "${name}-home";

            machine.imports = [
              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.sharedModules = [
                  self.nixosModules.home
                ];
                home-manager.users.root = { ... }: {
                  services.vscode-server-fixup.enable = true;
                };
              }
            ];

            testScript = ''
              machine.start()
              machine.wait_for_unit("multi-user.target")

              with subtest("Installs the systemd user service in home"):
                machine.succeed("test -f ${systemdUnitPathHome}")

              with subtest("Does not install the system-wide systemd user service"):
                machine.fail("test -f ${systemdUnitPathSystem}")
            '';
          };
        })
      )
      #
      # SYSTEM-INDEPENDENT OUTPUTS
      #
      {
        nixosModules = {
          system = import ./modules/nixos.nix;
          home = import ./modules/home.nix;
        };
      }
    ];
}
