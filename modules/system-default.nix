# dendritic: the shared NixOS base every host expects (ADR 0014, R3). Hosts
# import this aspect instead of the modules/_common directory; the feature
# files still live there and are migrated to their own flake.modules.nixos.<aspect>
# definitions incrementally.
_: {
  flake.modules.nixos.system-default = {
    imports = [ ./_common ];
  };
}
