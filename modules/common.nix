moduleConfig:
{ config, pkgs, lib, ... }:
with lib;
let
  svcName = "vscode-server-fixup";
  cfg = config.services.${svcName};
in
{
  options.services.${svcName} = {
    enable = mkEnableOption "automatic fixups for the VS Code remote SSH service";

    nodejsPackage = mkOption {
      type = types.package;
      description = ''  
        Which Node.js derivation to use.
      '';
      default = pkgs.nodejs-14_x;
      defaultText = literalExpression "pkgs.nodejs-14_x";
    };

    ripgrepPackage = mkOption {
      type = types.package;
      description = ''  
        Which ripgrep derivation to use.
      '';
      default = pkgs.ripgrep;
      defaultText = literalExpression "pkgs.ripgrep";
    };

    watchDirs = mkOption {
      type = types.listOf types.str;
      description = ''
        List of absolute directory paths to watch to apply automatic fixes.

        Accepts systemd specifiers (see systemd.unit(5)).
      '';
      default = [
        "%h/.vscode-server/bin"
        "%h/.vscode-server-oss/bin"
      ];
    };
  };

  config = moduleConfig rec {
    inherit lib;
    name = svcName;
    pathConfig = {
      description = "Watch for changes in directories created by the VS Code remote SSH extension";
      PathExistsGlob = map (x: "${x}/*/LICENSE") cfg.watchDirs;
      Unit = "${name}.service";
    };
    serviceConfig = {
      # This service keeps restarting until it replaced all the necessary binaries.
      description = "Fix binaries uploaded by the VS Code server remote SSH extension";
      Type = "oneshot";
      Restart = "on-failure";
      RestartSec = "500ms";
      StartLimitIntervalSec = 0; # disable
      ExecStart = "${pkgs.writeShellScript "${name}.sh" ''
        set -euo pipefail

        watch_dirs=( ''${@:1} )
        for dir in "''${watch_dirs[@]}"; do
          if [[ -d "$dir" ]]; then
            echo "Fixing $dir:"
            ${pkgs.findutils}/bin/find "$dir" -mindepth 2 -maxdepth 2 -name node -printf " - %p\n" \
              -exec ${pkgs.coreutils}/bin/ln -sfT ${cfg.nodejsPackage}/bin/node {} \; | ${pkgs.gnugrep}/bin/grep '^'
            ${pkgs.findutils}/bin/find "$dir" -path '*/vscode-ripgrep/bin/rg'    -printf " - %p\n" \
              -exec ${pkgs.coreutils}/bin/ln -sfT ${cfg.ripgrepPackage}/bin/rg  {} \; | ${pkgs.gnugrep}/bin/grep '^'

            ${pkgs.coreutils}/bin/rm "$dir"/*/LICENSE
            echo "Succesfully fixed $dir."
          fi
        done
      ''} ${concatMapStringsSep " " (x: lib.escapeShellArg x) cfg.watchDirs}";
    };
  };
}
