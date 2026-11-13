# Input manifest (ADR 0014): transcribed from the former flake.nix inputs
# block plus the two inputs the dendritic preset needs. Materialized into
# flake.nix by `nix run .#write-flake`; flake.lock is never rewritten by this
# file -- add/edit entries here, regenerate, then `nix flake lock`.
{
  flake-file.inputs = {
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?shallow=1&ref=nixos-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    # Raspberry Pi support for slinky (uConsole CM4). Pinned to the same
    # nixos-raspberrypi rev nixos-uconsole v1.1.1 is built against. Kernel and
    # firmware come from the vendor tree via nvmd's overlays, built on the
    # fleet's nixpkgs (follows).
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/v1.20260317.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # uConsole hardware support (kernel patches, config.txt, sleep/4G
    # modules). nixpkgs follows the fleet pin so slinky's toplevel matches
    # the rest of the fleet; the kernel reaches harmonia via ADR-0018.
    nixos-uconsole = {
      url = "github:nixos-uconsole/nixos-uconsole/v1.1.1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixos-raspberrypi.follows = "nixos-raspberrypi";
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

    affinity-nix = {
      url = "github:mrshmllow/affinity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
}
