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

  config.flake.lib.mkNixos = system: name: {
    ${name} = inputs.nixpkgs.lib.nixosSystem (
      if self.modules.nixos or { } ? ${name} then
        {
          modules = [
            self.modules.nixos.${name}
            { nixpkgs.hostPlatform = lib.mkDefault system; }
          ];
        }
      else
        {
          specialArgs = {
            inherit inputs;
            constants = import (inputs.self + "/global/constants.nix");
          };
          modules = [ (inputs.self + "/modules/hosts/${name}/_default.nix") ];
        }
    );
  };
}
