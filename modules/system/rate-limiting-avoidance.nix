# dendritic aspect (ADR 0014): rate-limiting-avoidance absorbed from _common/rate_limiting_avoidance.nix.
{ inputs, ... }: {
  flake.modules.nixos.rate-limiting-avoidance =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      imports = [
        inputs.sops-nix.nixosModules.sops
      ];
      nix = {
        extraOptions = "!include ${config.sops.secrets.nixAccessTokens.path}";
      };

      sops.secrets.nixAccessTokens = {
        mode = "0440";
        group = config.users.groups.keys.name;
      };
    };
}
