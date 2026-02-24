{
  description = "A simple NixOS flake";

  inputs = {
    # NixOS official package source, using the master branch here
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    #chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    impermanence.url = "github:nix-community/impermanence";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations.zurg = nixpkgs.lib.nixosSystem {
      modules = [
        # Import the previous configuration.nix we used,
        # so the old configuration file still takes effect
        ./configuration.nix
        #inputs.chaotic.nixosModules.default
        inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p51
        inputs.impermanence.nixosModules.impermanence
      ];
    };
  };
}
