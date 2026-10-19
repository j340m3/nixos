# Every directory in modules/hosts is one host-config; the folder name is
# the host name. Layout of the fleet roster itself lives in constants
# (global/constants.nix).
{ inputs, ... }:
let
  # Constants represent variables which are important for multiple hosts
  constants = import (inputs.self + "/global/constants.nix");

  mkHost =
    host:
    let
      inherit (inputs) nixpkgs;
    in
    {
      name = host;
      value = nixpkgs.lib.nixosSystem {
        specialArgs.inputs = inputs;
        specialArgs.constants = constants;
        modules = [ (inputs.self + "/modules/hosts/${host}") ];
      };
    };
in
{
  flake.nixosConfigurations = builtins.listToAttrs (
    map mkHost (builtins.attrNames (builtins.readDir (inputs.self + "/modules/hosts")))
  );
}
