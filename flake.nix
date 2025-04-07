{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";

    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    conduwuit = {
      url = "github:girlbossceo/conduwuit";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
  };
  outputs = { self, nixpkgs, nixpkgs-stable, sops-nix, home-manager, conduwuit, nixos-hardware, ... } @ inputs : 
  let
    inherit (self) outputs;
  in
  {
    nixosConfigurations.pricklepants = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs outputs;};
      system = "x86_64-linux";
      modules = [ 
        ./hosts/pricklepants/configuration.nix
        sops-nix.nixosModules.sops
      ];
    };
    nixosConfigurations.woody = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs outputs;};
      system = "x86_64-linux";
      modules = [ 
        #inputs.nixos-facter-modules.nixosModules.facter
        #  { config.facter.reportPath = ./hosts/woody/facter.json; }
        ./hosts/woody/configuration.nix
        sops-nix.nixosModules.sops
      ];
    };
    nixosConfigurations.lenny = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs outputs;};
      system = "x86_64-linux";
      modules = [ 
        ./hosts/lenny/configuration.nix
        nixos-hardware.nixosModules.lenovo-thinkpad-x230
        # sops-nix.nixosModules.sops
      ];
    };
    nixosConfigurations.rex = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs outputs;};
      system = "x86_64-linux";
      modules = [ 
        ./hosts/rex/configuration.nix
        sops-nix.nixosModules.sops
      ];
    };
    homeConfigurations = {
      # FIXME replace with your username@hostname
      "donquezz@pricklepants" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {inherit inputs outputs;};
        # > Our main home-manager configuration file <
        modules = [./home-manager/home.nix];
      };
    };
  };
}
