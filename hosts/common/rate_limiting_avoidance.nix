{
  config,
  pkgs,
  lib,
  ...
}: 
{
  nix = {
    extraOptions = ''!include ${config.sops.secrets.nixAccessTokens.path}'';
  };

  sops.secrets.nixAccessTokens = {
    mode = "0440";
    group = config.users.groups.keys.name;
  };
}