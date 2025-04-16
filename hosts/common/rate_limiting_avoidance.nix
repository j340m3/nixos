{
  config,
  pkgs,
  lib,
  ...
}: 
{
  nix = {
    settings = {
      access-tokens = "!include ${config.sops.secrets.nixAccessTokens.path}";
    };
  };

  sops.secrets.nixAccessTokens = {
    mode = "0440";
    group = config.users.groups.keys.name;
  };
}