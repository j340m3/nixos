# dendritic aspect (ADR 0014): trivial hygiene defaults every host repeats.
_: {
  flake.modules.nixos.basics =
    { lib, ... }:
    {
      # wipe /tmp on every boot (bootstrap base profiles did this locally)
      boot.tmp.cleanOnBoot = lib.mkDefault true;
    };
}
