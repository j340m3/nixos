# borg serve bridge listener: the RNS twin of borg-server.nix's sshd
# accept side. Separate RNS identity (sops reticulum/borg_identity), own
# group (audit F3), per-repo restrict-to-path (audit F1). The option gate
# (services.reticulum.rnshBorg) is set per host (woody).
{ inputs, ... }:
let
  constants = import ../global/_constants.nix;
in
{
  flake.modules.nixos.rnsh-borg =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.reticulum;
      host = config.networking.hostName;
      isPublic = lib.elem host constants.reticulum.publicHosts;

      rn = inputs.self.lib.rnsh {
        inherit pkgs;
        lxmf = isPublic;
      };
      inherit (rn) rnspython rnsh;

      allowBorgIdentities = lib.concatMapStringsSep " " (h: "-a ${h}") cfg.rnshBorg.allowIdentities;
    in
    {
      config = lib.mkIf cfg.enable {
        # group for the borg bridge identity + config copy only (audit F3):
        # deliberately disjoint from group `reticulum` (the nix-bridge side).
        users.groups.rnsh-borg = { };

        users.users.borg = lib.mkIf cfg.rnshBorg.enable {
          extraGroups = [ "rnsh-borg" ];
        };

        sops.secrets."reticulum/borg_identity" = lib.mkIf cfg.rnshBorg.enable {
            key = "borg_identity";
            sopsFile = ../../secrets/hosts/${host}/reticulum.yaml;
            # audit F3: 0400 root — the decode runs as root (the + ExecStartPre
            # below); nobody else reads the plaintext, and the borg user
            # reaches the decoded copy via group rnsh-borg only.
            owner = "root";
            group = "root";
            mode = "0400";
            restartUnits = [ "rnsh-borg.service" ];
        };

        # rnsh-borg is ALWAYS defined as an attribute here, gated instead of
        # mkIf'd away at the systemd.services level: an mkIf(false) at the
        # service-attribute level still auto-vivifies the
        # systemd.services.rnsh-borg name, and the merged (empty) entry then
        # makes the unit generator emit an ExecStart-less stub that systemd
        # rejects as "bad unit file setting". So: the attr always exists,
        # enable becomes mkForce false where the bridge is off (the unit
        # generator emits nothing for enable=false units), and the BODY is
        # inside mkIf so hosts without the woody-only identity constant
        # never evaluate it (pricklepants, 2026-11-08).
        systemd.services = {
          rnsh-borg = lib.mkMerge [
            {
              enable = lib.mkIf (!cfg.rnshBorg.enable) (lib.mkForce false);
            }
            (lib.mkIf cfg.rnshBorg.enable {
              description = "rnsh bridge for borg (append-only repos)";
              after = [
                "reticulum.service"
                "reticulum-identity.service"
              ];
              requires = [
                "reticulum.service"
                "reticulum-identity.service"
              ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                PartOf = [ "reticulum.service" ];
                Restart = "always";
                RestartSec = "3s";
                LimitNOFILE = 1024;
                User = "borg";
                Group = "borg";
                # clients read repo paths against the serving process CWD
                WorkingDirectory = "${cfg.rnshBorg.repoPath}";
                # borg's home is /var/empty (root-owned); RNS needs a writable HOME
                Environment = "HOME=/run/rnsh-borg";
                RuntimeDirectory = "rnsh-borg";
                # audit F6: borg serve only ever writes the repoPath tree
                NoNewPrivileges = true;
                ProtectSystem = "strict";
                ReadWritePaths = [ "${cfg.rnshBorg.repoPath}" "/run/rnsh-borg" ];
                ProtectHome = true;
                PrivateTmp = true;
                PrivateDevices = true;
                ProtectKernelTunables = true;
                ProtectKernelModules = true;
                ProtectKernelLogs = true;
                ProtectControlGroups = true;
                ProtectClock = true;
                ProtectHostname = true;
                RestrictNamespaces = true;
                RestrictRealtime = true;
                RestrictSUIDSGID = true;
                LockPersonality = true;
                RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
                CapabilityBoundingSet = "";
                SystemCallArchitectures = "native";
                # the bridge identity is borg-only: decode happens here as root
                ExecStartPre = "+${
                  pkgs.writeShellScript "rnsh-borg-identity" ''
                    ${pkgs.coreutils}/bin/tr '_-' '/+' < ${
                      config.sops.secrets."reticulum/borg_identity".path
                    } | ${pkgs.coreutils}/bin/base64 -d > /run/rnsh-borg/identity-borg
                    # audit F3: this identity is borg-only (group rnsh-borg),
                    # never group reticulum — the nix-bridge account must not be
                    # able to read (and impersonate) the borg bridge identity.
                    chown root:borg /run/rnsh-borg/identity-borg
                    chmod 0440 /run/rnsh-borg/identity-borg
                    ${pkgs.coreutils}/bin/ln -sfn /run/reticulum-borg/config /run/rnsh-borg/config
                  ''
                }";
              };
              script = ''
                # The identity lives in THIS unit's runtime dir (decoded by the
                # + ExecStartPre above, 0440 root:borg). Keep the -i paths here
                # in sync with that decode path - a stale
                # /run/reticulum/identity-borg here made the rnid gate see an
                # empty hash and crash-loop every 3 s (woody, 2026-11-14).
                expected=${constants.reticulum.identities.${host}.borg}
                actual=$(${rnspython}/bin/rnid --config /run/rnsh-borg -i /run/rnsh-borg/identity-borg -H rnsh 2>/dev/null | ${pkgs.gnugrep}/bin/grep 'rnsh destination' | ${pkgs.gnugrep}/bin/grep -oE '[0-9a-f]{32}' || true)
                if [ "$actual" != "$expected" ]; then
                  echo "rnsh-borg: destination hash mismatch: expected $expected, got '$actual'" >&2
                  exit 1
                fi
                exec ${rnsh}/bin/rnsh --rnsconfig /run/rnsh-borg -l -b 900 -C -i /run/rnsh-borg/identity-borg \
                  ${allowBorgIdentities} \
                  -- ${config.services.borgbackup.package}/bin/borg serve --append-only --restrict-to-path ${cfg.rnshBorg.repoPath}
              '';
            })
          ];
        };
      };
    };
}
