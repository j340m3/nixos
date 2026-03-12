{
  inputs,
  ...
}:
{
  flake-file.inputs = {
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.inputs.home-manager.follows = "home-manager";
  };

  imports = [ inputs.sops-nix.nixosModules.sops ];
}
