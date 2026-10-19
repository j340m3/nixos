# Host self-declaration helper: every host dir declares itself into the flake
# with a one-liner flake-parts.nix (see modules/hosts/*/flake-parts.nix).
{ inputs, ... }:
{
  flake.lib.mkNixos =
    host:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs.inputs = inputs;
      specialArgs.constants = import (inputs.self + "/global/constants.nix");
      modules = [ (inputs.self + "/modules/hosts/${host}") ];
    };
}
