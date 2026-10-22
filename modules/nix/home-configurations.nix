# home-manager configurations: standalone. Shares the same source with the
# per-host wiring (rex/lenny): the jeromeb HM aspect group in modules/home/.
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
      modules = [ inputs.self.modules.homeManager.jeromeb ];
    };
  };
}
