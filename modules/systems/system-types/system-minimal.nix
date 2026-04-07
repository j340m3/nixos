{
  inputs,
  ...
}:
{
  # default settings needed for all nixosConfigurations

  flake.modules.nixos.system-minimal =
    { pkgs, ... }:
    {

      nixpkgs.overlays = [
        (final: _prev: {
          unstable = import inputs.nixpkgs {
            inherit (final) config;
            system = pkgs.stdenv.hostPlatform.system;
          };
        })
      ];
      system.stateVersion = "25.05";
    };
}
