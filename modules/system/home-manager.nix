# dendritic aspect (ADR 0014): home-manager absorbed from _common/home-manager.nix.
{ inputs, ... }: {
  flake.modules.nixos.home-manager =
    {
      ...
    }:
    {
      imports = [ inputs.home-manager.nixosModules.home-manager ];

      home-manager = {
        # useGlobalPkgs breaks: stylix target overlay modules always define a
        # top-level `overlay`, which home-manager promotes to `nixpkgs.overlays`
        # and useGlobalPkgs asserts on. Home Manager builds its own nixpkgs
        # instead, same as the standalone homeConfigurations did.
        useGlobalPkgs = false;
        useUserPackages = true;
        # Transition guard: never clobber files left by standalone `home-manager switch`
        backupFileExtension = "hm-backup";
        extraSpecialArgs = { inherit inputs; };
      };
    };
}
