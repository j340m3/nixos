{
  inputs = {
    #nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    
  };
  outputs = { self, nixpkgs, sops-nix, home-manager, ... } @ inputs : 
  let
    inherit (self) outputs;
  in
  {
    nixosConfigurations.nixos-gb = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs outputs;};
      system = "x86_64-linux";
      modules = [ 
        ./configuration.nix
        sops-nix.nixosModules.sops
      ];
    };
  };
}
