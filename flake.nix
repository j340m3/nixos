{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    inputs.sops-nix.url = "github:Mic92/sops-nix";
    # optional, not necessary for the module
    inputs.sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    #nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
