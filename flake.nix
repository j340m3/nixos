{
  description = "jeromeb's NixOS/home-manager flake";

  # =============================================================================
  # Inputs
  # =============================================================================

  inputs = {
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    # Shallow cloning
    # Source: https://tsawyer87.github.io/posts/nix_flakes_tips/
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?shallow=1&ref=nixos-unstable";
    #nixpkgs-2411.url = "github:NixOS/nixpkgs/nixos-24.11";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Pinned to the same rev as /etc/nixos (newer revs have a broken bun build).
    opencode-dev.url = "github:anomalyco/opencode/88c6c7abc7f320b6aabed2634ac0b2d6e6ecea67";

    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    impermanence.url = "github:nix-community/impermanence";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    oom-hardware = {
      url = "github:j340m3/oom-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixos-hardware.follows = "nixos-hardware";
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

    affinity-nix.url = "github:mrshmllow/affinity-nix";
    affinity-nix.inputs.nixpkgs.follows = "nixpkgs";

    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";

    peerpatrol = {
      url = "github:j340m3/peerpatrol";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # =============================================================================
  # Outputs
  # =============================================================================
  # All config plumbing lives under ./modules/flake — this entry file only
  # wires the inputs and auto-imports that tree. NixOS modules (modules/*.nix,
  # modules/hosts/*) are deliberately NOT auto-imported here: they are NixOS
  # modules, not flake-parts modules, and stay wired up exclusively by
  # modules/flake/hosts.nix.

  outputs =
    inputs@{ flake-parts, ... }:
    let
      hasNixSuffix =
        name:
        let
          l = builtins.stringLength name;
        in
        l >= 4 && builtins.substring (l - 4) 4 name == ".nix";

      # Import every .nix file in a directory tree, recursing into
      # subdirectories. Same idea as vic's import-tree; local copy so the
      # flake does not grow an extra input for a 10-line helper.
      importTree =
        path:
        builtins.foldl' (acc: x: acc ++ x) [ ] (
          builtins.attrValues (
            builtins.mapAttrs (
              name: type:
              if type == "directory" then
                importTree (path + "/${name}")
              else if hasNixSuffix name then
                [ (import (path + "/${name}")) ]
              else
                [ ]
            ) (builtins.readDir path)
          )
        );
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = importTree ./modules/flake;
    };
}
