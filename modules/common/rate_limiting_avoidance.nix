{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: 
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];
  nix = {
    extraOptions = ''!include ${config.sops.secrets.nixAccessTokens.path}'';
  };

  sops.secrets.nixAccessTokens = {
    mode = "0440";
    group = config.users.groups.keys.name;
  };
}