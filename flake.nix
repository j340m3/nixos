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
    #nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11"; # TODO: Remove unused
    #nixpkgs-2411.url = "github:NixOS/nixpkgs/nixos-24.11";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

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

    peerix = {
      url = "github:j340m3/peerix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Pinned to the same rev as /etc/nixos (newer revs have a broken bun build).
    opencode-dev.url = "github:anomalyco/opencode/88c6c7abc7f320b6aabed2634ac0b2d6e6ecea67";

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

    apple-fonts.url = "github:Lyndeno/apple-fonts.nix";
    apple-fonts.inputs.nixpkgs.follows = "nixpkgs";

    affinity-nix.url = "github:mrshmllow/affinity-nix";
    affinity-nix.inputs.nixpkgs.follows = "nixpkgs";

    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
  };

  # =============================================================================
  # Outputs
  # =============================================================================

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      home-manager,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { self, ... }:
      let
        # Constants represent variables which are important for multiple hosts
        constants = import ./global/constants.nix;

        mkHost = base: host: {
          name = host;
          value = nixpkgs.lib.nixosSystem {
            specialArgs.inputs = inputs;
            specialArgs.constants = constants;
            modules = [
              inputs.chaotic.nixosModules.default
              (base + "/${host}")
            ];
          };
        };
      in
      {
        # Only x86_64 hosts need per-system outputs (devShell, checks, images).
        # aarch64 hosts (slinky) still build from flake.nixosConfigurations.
        systems = [ "x86_64-linux" ];

        flake = {
          # ---------------------------------------------------------------------------
          # NixOS Hosts - Each folder in ./hosts is one host-config
          # ---------------------------------------------------------------------------
          nixosConfigurations = builtins.listToAttrs (
            (map (mkHost ./hosts/graphical) (builtins.attrNames (builtins.readDir ./hosts/graphical)))
            ++ (map (mkHost ./hosts/headless) (builtins.attrNames (builtins.readDir ./hosts/headless)))
          );

          # ---------------------------------------------------------------------------
          # home-manager configurations
          # ---------------------------------------------------------------------------
          homeConfigurations = {
            "jeromeb" = home-manager.lib.homeManagerConfiguration {
              pkgs = import nixpkgs {
                system = "x86_64-linux";
                config.permittedInsecurePackages = [
                  "radicle-node-1.10.3"
                ];
              };
              extraSpecialArgs = { inherit inputs; };
              modules = [
                ./home
              ];
            };
          };
        };

        perSystem =
          {
            pkgs,
            system,
            lib,
            ...
          }:
          {
            packages =
              let
                # disko passes a module tree (`aggregateModules`) to vmTools as
                # its `kernel`. Newer nixpkgs rejects a `kernel` without a
                # `target` attribute and expects module trees via
                # `kernelModules`, which disko does not set yet. Tagging the
                # aggregate restores the previous behaviour. Scoped to the image
                # builders only; assumes an x86_64 kernel image ("bzImage").
                diskoImageCompat = {
                  nixpkgs.overlays = [
                    (_final: prev: {
                      aggregateModules =
                        modules:
                        (prev.aggregateModules modules).overrideAttrs (old: {
                          passthru = (old.passthru or { }) // {
                            target = "bzImage";
                          };
                        });
                    })
                  ];
                };
                mkImage =
                  host:
                  (self.nixosConfigurations.${host}.extendModules {
                    modules = [ diskoImageCompat ];
                  }).config.system.build.diskoImages;
              in
              {
                image = mkImage "bootstrap";
                image-impermanent = mkImage "bootstrap-impermanent";
              };

            formatter = pkgs.nixfmt;

            devShells.default = pkgs.mkShell {
              packages = with pkgs; [
                age
                deadnix
                jq
                just
                nixfmt
                nixos-rebuild
                shellcheck
                sops
                statix
                (python3.withPackages (ps: [ ps.pyyaml ]))
              ];
            };

            # Evaluate (without building) every native NixOS configuration so
            # broken imports/options surface in CI and via
            # `nix build .#checks.x86_64-linux.<host>`. Foreign-system hosts
            # (e.g. the aarch64 uConsole) are skipped.
            checks =
              let
                evalCheck =
                  name: cfg:
                  pkgs.runCommand "eval-${name}" { } ''
                    echo ${builtins.unsafeDiscardStringContext cfg.config.system.build.toplevel.drvPath} > "$out"
                  '';
                native = lib.filterAttrs (
                  _: cfg: cfg.config.nixpkgs.hostPlatform.system == system
                ) self.nixosConfigurations;

                enabled = self.nixosConfigurations.mrpotatohead.config;
                disabled = self.nixosConfigurations.lenny.config;

                # Guards the upgrade-health module's observable behaviour: the two
                # services exist and honour the settle delay when enabled, and
                # neither exists when a host does not opt in.
                upgradeHealthCheck =
                  assert enabled.upgradeHealth.enable;
                  assert enabled.systemd.services ? nixos-upgrade-health;
                  assert enabled.systemd.services ? nixos-upgrade-health-schedule;
                  assert lib.hasInfix "--on-active=${enabled.upgradeHealth.settleDelay}"
                    enabled.systemd.services.nixos-upgrade-health-schedule.script;
                  assert !(disabled.systemd.services ? nixos-upgrade-health);
                  assert !(disabled.systemd.services ? nixos-upgrade-health-schedule);
                  pkgs.runCommand "upgrade-health-check" { } "touch $out";
              in
              builtins.mapAttrs evalCheck native // { upgrade-health = upgradeHealthCheck; };
          };
      }
    );
}
