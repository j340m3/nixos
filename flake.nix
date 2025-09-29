{
  inputs = {
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-2411.url = "github:NixOS/nixpkgs/nixos-24.11";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    home-manager.url = "github:nix-community/home-manager/master";
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
      #url = "github:robertjakub/oom-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixos-hardware.follows = "nixos-hardware";
    };

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.93.2-1.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { nixpkgs, nixpkgs-master, nixpkgs-stable, nixpkgs-2411, sops-nix, home-manager, comin, nixos-hardware, peerix, oom-hardware, chaotic, stylix,... } @ inputs: 
  let
    inherit (nixpkgs) lib;
    constants = (import ./global/constants.nix);
  in
  {
    /* nixpkgs-master.overlays = [ (final: prev: {
    inherit (final.lixPackageSets.stable)
      nixpkgs-review
      nix-direnv
      nix-eval-jobs
      nix-fast-build
      colmena;
  }) ]; */

    nixosConfigurations = builtins.listToAttrs (
      map (host: {
        name = host;
        value = nixpkgs-master.lib.nixosSystem {
          specialArgs.inputs = inputs;
          specialArgs.constants = constants;
          modules = [ 
            #inputs.home-manager.nixosModules.home-manager
            #inputs.stylix.nixosModules.stylix
            ./hosts/${host} 
            inputs.chaotic.nixosModules.default
            #inputs.lix-module.nixosModules.default
          ];
        };
      }) (builtins.attrNames (builtins.readDir ./hosts))
    );
    homeConfigurations = {
      # FIXME replace with your username@hostname
      "jeromeb" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {system = "x86_64-linux";};
        extraSpecialArgs = {};
        # > Our main home-manager configuration file <
        modules = [
          /* home-manager.nixosModules.home-manager
          {
            home = {
              username = "jeromeb";
              homeDirectory = "/home/jeromeb";
            };
          } */
          inputs.stylix.homeModules.stylix
          ./home
          #inputs.plasma-manager.homeModules.plasma-manager
          #./home/kde/plasma.nix
        ];
        #programs.home-manager.enable = true;
      };
    };
    # packages.x86_64-linux = {
    #   image = self.nixosConfigurations.bootstrap.config.system.build.diskoImages;
    # };
  };
}
