{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-2411.url = "github:NixOS/nixpkgs/nixos-24.11";

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
      url = "github:j340m3/peerix";
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

    oom-hardware ={
      url = "github:j340m3/oom-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixos-hardware.follows = "nixos-hardware";
    };

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.93.2-1.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, nixpkgs-stable, nixpkgs-2411, sops-nix, home-manager, nixos-hardware, peerix, oom-hardware, ... } @ inputs : 
  let
    inherit (self) outputs;
    inherit (nixpkgs) lib;
  in
  {
    nixosConfigurations = builtins.listToAttrs (
      map (host: {
        name = host;
        value = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs lib;
          };
          modules = [ ./hosts/${host} ];
        };
      }) (builtins.attrNames (builtins.readDir ./hosts))
    );
    /* nixosConfigurations.pricklepants = nixpkgs.lib.nixosSystem {
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
      system = "x86_64-linux";
      specialArgs = {
        inherit inputs outputs;
        pkgs-2411 = import nixpkgs-2411 {
            # Refer to the `system` parameter from
            # the outer scope recursively
            system = "x86_64-linux";
            # To use Chrome, we need to allow the
            # installation of non-free software.
            config.allowUnfree = true;
          };
      };
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
    nixosConfigurations.jessie = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs outputs;};
      system = "x86_64-linux";
      modules = [ 
        ./hosts/jessie/configuration.nix
        sops-nix.nixosModules.sops
        inputs.disko.nixosModules.disko
        inputs.impermanence.nixosModules.impermanence
      ];
    }; 
    nixosConfigurations.slinky = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs outputs;};
      system = "aarch64-linux";
      modules = [ 
        ./hosts/slinky/configuration.nix
        sops-nix.nixosModules.sops
        nixos-hardware.nixosModules.raspberry-pi-4
        oom-hardware.nixosModules.uconsole
      ];
    }; */
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
