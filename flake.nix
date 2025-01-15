{
  inputs = {
    #nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    sops-nix.url = "github:Mic92/sops-nix";
    # optional, not necessary for the module
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    
  };
  outputs = inputs@{ self, nixpkgs, sops-nix, ... }: {
    nixosConfigurations.nixos-gb = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ 
        ./configuration.nix
        sops-nix.nixosModules.sops
      ];
    };
  };
}
