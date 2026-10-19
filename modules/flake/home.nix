# home-manager configurations: standalone (not per-host yet), importing the
# shared ./home tree.
{ inputs, ... }:
{
  flake.homeConfigurations = {
    "jeromeb" = inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import inputs.nixpkgs {
        system = "x86_64-linux";
        config.permittedInsecurePackages = [
          "radicle-node-1.10.3"
        ];
        config.allowUnfreePredicate =
          pkg:
          builtins.elem (inputs.nixpkgs.lib.getName pkg) [
            "spotify"
            "apple_cursor"
          ];
      };
      extraSpecialArgs = { inherit inputs; };
      modules = [ (inputs.self + "/home") ];
    };
  };
}
