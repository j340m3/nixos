# dendritic aspect (ADR 0014): network domain absorbed from _common/domain.nix.
_: {
  flake.modules.nixos.domain =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      networking.domain = "hosts.kauderwels.ch";
    };
}
