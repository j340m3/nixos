# dendritic: ssh-identities feature (ADR 0014 transitional): thin aspect over the parked
# plain module it used to be imported by path as (modules/_common/ssh-identities.nix);
# absorb the module body here per-feature in a follow-up.
_: {
  flake.modules.nixos.ssh-identities = {
    imports = [ ../_common/ssh-identities.nix ];
  };
}
