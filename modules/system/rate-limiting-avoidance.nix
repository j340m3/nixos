# dendritic: rate-limiting-avoidance feature (ADR 0014 transitional): thin aspect over the parked
# plain module it used to be imported by path as (modules/_common/rate_limiting_avoidance.nix);
# absorb the module body here per-feature in a follow-up.
_: {
  flake.modules.nixos.rate-limiting-avoidance = {
    imports = [ ../_common/rate_limiting_avoidance.nix ];
  };
}
