{ inputs, self, ... }:
{
  # Only x86_64 hosts need per-system outputs (devShell, checks, images).
  # aarch64 hosts (slinky) still build from flake.nixosConfigurations.
  systems = [ "x86_64-linux" ];

  perSystem =
    {
      pkgs,
      system,
      lib,
      ...
    }:
    let
      # Constants represent variables which are important for multiple hosts
      constants = import ../global/_constants.nix;

      # Lint staged files at commit time (installed into the devShell) and
      # the whole tree via `checks.pre-commit`.
      preCommit = inputs.pre-commit-hooks.lib.${system}.run {
        src = inputs.self;
        hooks = {
          # NixOS/home-manager modules conventionally take unused args
          # (`lib`, `config`); don't flag those.
          deadnix = {
            enable = true;
            args = [ "--no-lambda-pattern-names" ];
          };
          statix.enable = true;
          shellcheck.enable = true;
          ruff.enable = true;
        };
      };
    in
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
        packages =
          (with pkgs; [
            age
            deadnix
            jq
            just
            nixfmt
            nixos-rebuild
            rbw
            shellcheck
            sops
            statix
            (python3.withPackages (ps: [ ps.pyyaml ]))
          ])
          ++ preCommit.enabledPackages;
        shellHook = ''
          ${preCommit.shellHook}
          export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/rbw/ssh-agent-socket"
        '';
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

          # Guards the peerpatrol fleet wiring: the unit exists and is
          # enabled, LoadCredential points at the sops secret aliases,
          # and the ping targets match the roster hosts that have a
          # verified nebula ip.
          peerpatrolCheck =
            assert enabled.services.peerpatrol.enable;
            assert enabled.systemd.services ? peerpatrol;
            assert lib.hasInfix "peerpatrol-token-file:${enabled.sops.secrets."telegram/bot_token".path}" (
              lib.concatStringsSep "\n" enabled.systemd.services.peerpatrol.serviceConfig.LoadCredential
            );
            assert lib.hasInfix "peerpatrol-chat-id-file:${enabled.sops.secrets."telegram/group_id".path}" (
              lib.concatStringsSep "\n" enabled.systemd.services.peerpatrol.serviceConfig.LoadCredential
            );
            assert lib.hasInfix "--token-file %d/peerpatrol-token-file"
              enabled.systemd.services.peerpatrol.serviceConfig.ExecStart;
            assert lib.hasInfix "--chat-id-file %d/peerpatrol-chat-id-file"
              enabled.systemd.services.peerpatrol.serviceConfig.ExecStart;
            assert 5 == lib.length (lib.filter (h: h ? ip) (lib.attrValues constants.host));
            pkgs.runCommand "peerpatrol-check" { } "touch $out";
        in
        builtins.mapAttrs evalCheck native
        // {
          upgrade-health = upgradeHealthCheck;
          peerpatrol = peerpatrolCheck;
          pre-commit = preCommit;
        };
    };
}
