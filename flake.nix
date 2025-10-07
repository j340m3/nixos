{
# =============================================================================
# Inputs
# =============================================================================

  inputs = {
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05"; #TODO: Remove unused
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

    tinted-schemes = {
      flake = false;
      url = "github:tinted-theming/schemes";
    };

    # Apple font
    apple-fonts.url = "github:Lyndeno/apple-fonts.nix";
    apple-fonts.inputs.nixpkgs.follows = "nixpkgs";
  };

# =============================================================================
# Outputs
# =============================================================================

  outputs = { nixpkgs, nixpkgs-master, nixpkgs-stable, nixpkgs-2411, sops-nix, home-manager, comin, nixos-hardware, peerix, oom-hardware, chaotic, stylix,... } @ inputs: 
  let
    inherit (nixpkgs) lib;
    # Constants represent variables which are important for multiple hosts
    constants = (import ./global/constants.nix);
  in
  {

# -----------------------------------------------------------------------------
# NixOS Hosts - Each folder in ./hosts is one host-config
# ----------------------------------------------------------------------------- 

    nixosConfigurations = builtins.listToAttrs (
      (map (host: {
        name = host;
        value = nixpkgs.lib.nixosSystem {
          specialArgs.inputs = inputs;
          specialArgs.constants = constants;
          modules = [ 
            ./hosts/graphical/${host} 
            inputs.chaotic.nixosModules.default
          ];
        };
      }) (builtins.attrNames (builtins.readDir ./hosts/graphical))) ++
      (map (host: {
        name = host;
        value = nixpkgs-master.lib.nixosSystem {
          specialArgs.inputs = inputs;
          specialArgs.constants = constants;
          modules = [ 
            ./hosts/headless/${host} 
            inputs.chaotic.nixosModules.default
          ];
        };
      }) (builtins.attrNames (builtins.readDir ./hosts/headless)))
    );
# -----------------------------------------------------------------------------
# home-manager configurations
# -----------------------------------------------------------------------------
    homeConfigurations = {
      "jeromeb" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {system = "x86_64-linux";};
        extraSpecialArgs = {inherit inputs; };
        modules = [
          ./home
        ];
      };
    };
    # packages.x86_64-linux = {
    #   image = self.nixosConfigurations.bootstrap.config.system.build.diskoImages;
    # };
  };
}
