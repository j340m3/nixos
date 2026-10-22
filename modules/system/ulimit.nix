# dendritic: ulimit feature (ADR 0014 transitional): thin aspect over the parked
# plain module it used to be imported by path as (modules/_common/ulimit.nix);
# absorb the module body here per-feature in a follow-up.
_: {
  flake.modules.nixos.ulimit = {
    imports = [ ../_common/ulimit.nix ];
  };
}
