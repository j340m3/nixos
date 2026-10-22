# dendritic aspect (ADR 0014): sops absorbed from _common/sops.nix.
_: {
  flake.modules.nixos.sops =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      sops.defaultSopsFile = ../../secrets/shared.yaml;
      #sops.age.generateKey = true;
    };
}
