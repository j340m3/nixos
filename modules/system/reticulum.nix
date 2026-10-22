# dendritic: reticulum feature (ADR 0014 transitional): thin aspect over the
# parked plain module ../../_reticulum.nix (used to be imported by the
# aggregator); absorb the module body here per-feature in a follow-up.
_: {
  flake.modules.nixos.reticulum = {
    imports = [ ../_reticulum.nix ];
  };
}
