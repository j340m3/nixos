{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";

    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

     # kde
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    /* conduwuit = {
      url = "github:girlbossceo/conduwuit";
      inputs.nixpkgs.follows = "nixpkgs";
    }; */
    peerix = {
      url = "github:cid-chan/peerix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    impermanence.url = "github:nix-community/impermanence";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, nixpkgs-stable, sops-nix, home-manager, nixos-hardware, peerix,... } @ inputs : 
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
        peerix.nixosModules.peerix
      ];
    };
    nixosConfigurations.woody = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs outputs;};
      system = "x86_64-linux";
      modules = [ 
        peerix.nixosModules.peerix
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
        sops-nix.nixosModules.sops
        peerix.nixosModules.peerix
      ];
    };
    nixosConfigurations.rex = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs outputs;};
      system = "x86_64-linux";
      modules = [ 
        ./hosts/rex/configuration.nix
        sops-nix.nixosModules.sops
        peerix.nixosModules.peerix
      ];
    };
    nixosConfigurations.bootstrap = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs outputs;};
      system = "x86_64-linux";
      modules = [ 
        ./hosts/bootstrap/configuration.nix
        sops-nix.nixosModules.sops
        inputs.disko.nixosModules.disko
        inputs.impermanence.nixosModules.impermanence
      ];
    };
    nixosConfigurations.buzz = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs outputs;};
      system = "x86_64-linux";
      modules = [ 
        ./hosts/buzz/configuration.nix
        sops-nix.nixosModules.sops
        inputs.disko.nixosModules.disko
        inputs.impermanence.nixosModules.impermanence
        peerix.nixosModules.peerix
      ];
    };
    homeConfigurations = {
      # FIXME replace with your username@hostname
      "jeromeb" = home-manager.lib.homeManagerConfiguration {
        system = "x86_64-linux";
        pkgs = import nixpkgs;
        extraSpecialArgs = {inherit inputs outputs;};
        # > Our main home-manager configuration file <
        modules = [
          home-manager.nixosModules.home-manager
          inputs.plasma-manager.homeManagerModules.plasma-manager
          ./home/kde/plasma.nix
          
          {
            home = {
              username = "jeromeb";
              homeDirectory = "/home/jeromeb";
            };
          }
        ];
        programs.home-manager.enable = true;
      };
    };
    packages.x86_64-linux = {
      image = self.nixosConfigurations.bootstrap.config.system.build.diskoImages;
    };
  };
}
