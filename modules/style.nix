{
  inputs,
  ...
}:
{
  flake-file.inputs = {
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  flake.modules.homeManager.stylix = {
    imports = [
      inputs.stylix.homeModules.stylix
    ];
  };
  #imports = [ inputs.home-manager.flakeModules.home-manager ];
}
