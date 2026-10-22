# Host aspect (ADR 0014): flake.modules.nixos.bootstrap is assembled by lib.mkNixos
# (modules/nix/lib.nix); the flake-parts.nix one-liner next to this file
# declares the host into the flake. inputs arrive via the transitional
# specialArgs in the factory, so the head args stay verbatim.
{ inputs, lib, ... }:

{
  flake.modules.nixos.bootstrap =
    { ... }:
    {
      imports = [
        inputs.self.modules.nixos.bootstrap-base
      ];
    };
}
