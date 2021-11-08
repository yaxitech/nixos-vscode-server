import ./common.nix (
  { name, serviceConfig, pathConfig, lib }:
  let
    /* Filter an attribute set by removing all attributes with a name that
      does not start with an uppercase character. Not recursive.

      Example:
      filterStartsWithUppercase { wurzel = 1; Propf = "miau"; }
      => { Propf = "miau"; }
    */
    filterStartsWithUppercase = attrset: with lib; filterAttrs (n: v: elem (substring 0 1 n) upperChars) attrset;
  in
  {
    systemd.user.services.${name} = {
      Unit.Description = serviceConfig.description;
      Service = filterStartsWithUppercase serviceConfig;
    };

    systemd.user.paths.${name} = {
      Unit.Description = pathConfig.description;
      Path = filterStartsWithUppercase pathConfig;
      Install.WantedBy = [ "default.target" ];
    };
  }
)
