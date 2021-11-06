# vscode-server-fixup

Automatically fix binaries deployed by the [Visual Studio Code Remote SSH extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh).

As binaries are fixed after the extension installs them,
you likely have to click "Retry" when connecting to a remote host though VS Code for the first time.

## Installation with Nix Flakes

Add an input for this repository:

```Nix
{
  inputs.vscode-server-fixup.url = "github:yaxitech/vscode-server-fixup";
}
```

### NixOS module

```Nix
{
  outputs = { nixpkgs, vscode-server-fixup, ... }: {
    nixosConfigurations = {
      hostname = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          vscode-server-fixup.nixosModules.system
          {
            services.vscode-server-fixup.enable = true;
          }
        ];
      };
    };
  };
}
```

Activate the unit for your user by issuing:

```Shell
systemctl --user enable vscode-server-fixup.path
systemctl --user start  vscode-server-fixup.path
```

### Home Manager module

Extend your `nixosConfigurations` as follows:

```Nix
{
  outputs = { nixpkgs, home-manager, vscode-server-fixup, ... }: {
    nixosConfigurations = {
      hostname = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          vscode-server-fixup.nixosModules.system
          home-manager.nixosModules.home-manager
          {
            home-manager.sharedModules = [
              nixos-vscode-server.nixosModules.vscode-server-home
            ];
            home-manager.users."wurzelpfropf" = { ... }: {
              services.vscode-server-fixup.enable = true;
            };
          }
        ];
      };
    };
  };
}
```