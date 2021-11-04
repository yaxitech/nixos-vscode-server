import ./common.nix (
  { name, serviceConfig, pathConfig }:
  {
    systemd.user.services.${name} = {
      Unit.Description = serviceConfig.Description;
      Service = serviceConfig;
    };

    systemd.user.paths.${name} = {
      Unit.Description = pathConfig.Description;
      Path = pathConfig;
      Install.WantedBy = [ "default.target" ];
    };
  }
)
