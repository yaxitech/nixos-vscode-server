import ./module.nix (
  { name, serviceConfig, pathConfig }:
  {
    systemd.user.services.${name} = {
      inherit serviceConfig;
      enable = true;
    };

    systemd.user.paths.${name} = {
      inherit pathConfig;
      enable = true;
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
    };
  }
)
