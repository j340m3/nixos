# Host self-declaration helper: every host dir declares itself into the flake
# with a one-liner flake-parts.nix (see modules/hosts/*/flake-parts.nix).
#
# Every host publishes a module to self.modules.nixos.<name> (ADR 0014, end
# state): the factory wires it as the host module and pins the platform.
# Inputs/constants reach the modules lexically via wrapper closure `let`s;
# specialArgs is retired.
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
    ${name} = inputs.nixpkgs.lib.nixosSystem {
      modules = [
        self.modules.nixos.${name}
        { nixpkgs.hostPlatform = lib.mkDefault system; }
      ];
    };
  };
}
