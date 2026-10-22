# Host self-declaration helper: every host dir declares itself into the flake
# with a one-liner flake-parts.nix (see modules/hosts/*/flake-parts.nix).
#
# Transitional two-idiom dispatch (ADR 0014): converted hosts publish a
# module to self.modules.nixos.<name>; unconverted hosts are a plain
# _default.nix imported by path (kept out of the auto-imported tree by the
# leading underscore), with inputs/constants still passed via specialArgs.
{
  inputs,
  self,
  lib,
  ...
}:
{
  options.flake.lib = lib.mkOption {
    type = lib.types.attrsOf lib.types.unspecified;
    default = { };
  };

  # Transitional (ADR 0014): aspect-mode hosts keep specialArgs inputs/
  # constants so their still-plain-module siblings (e.g. bootstrap/_default.nix
  # with `imports = [ inputs.disko... ]`) resolve without a config-dependent
  # _module.args shim — those recurse infinitely at module-collection time.
  # Drop this block once the last plain sibling has become an aspect.
  config.flake.lib.mkNixos = system: name: {
    ${name} = inputs.nixpkgs.lib.nixosSystem {
      # Transitional only (ADR 0014): siblings (users/, modules/_*) still consume
      # inputs/constants directly, including in `imports` lists (_common/update.nix
      # uses inputs.comin), where `_module.args` cannot reach without recursing
      # through config. Retired once no such consumer remains.
      specialArgs = {
        inherit inputs;
        constants = import (inputs.self + "/global/constants.nix");
      };
      modules =
        if self.modules.nixos or { } ? ${name} then
          [
            self.modules.nixos.${name}
            { nixpkgs.hostPlatform = lib.mkDefault system; }
          ]
        else
          [ (inputs.self + "/modules/hosts/${name}/_default.nix") ];
    };
  };
}
