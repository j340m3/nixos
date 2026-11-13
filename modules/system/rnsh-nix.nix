# nix-daemon bridge listener: serves `nix-daemon --stdio` over an rnsh
# link, the RNS twin of the nebula ssh-ng remote-builder path. The
# allowlist is the remote-build/substituter client roster (buildHosts);
# the accept side of the same contract lives in
# modules/services/remote-builder.nix (authorizedKeys).
{ inputs, ... }:
let
  constants = import ../global/_constants.nix;
in
{
  flake.modules.nixos.rnsh-nix =
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

      # Audit F4: only hosts that actually dial the nix daemon — the
      # remote-build/substituter client roster (buildHosts keys = the
      # `builders` roster). The old attrNames identities allowlist granted
      # lenny/rex/slinky/mrpotatohead a bridge they don't have on the ssh
      # side (their keys are commented out there); self-dial is excluded.
      allowedIdentities = lib.concatMapStringsSep " " (
        h: "-a ${constants.reticulum.identities.${h}.hash}"
      ) (lib.filter (h: h != host) (lib.attrNames constants.buildHosts));
    in
    {
      config = lib.mkIf cfg.enable {
        systemd.services.rnsh-nix = {
          description = "rnsh bridge for the Nix daemon";
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
            # Downgraded from root: identity is the authorized_keys equivalent,
            # the remotebuild account is the factor between peer and daemon —
            # byte-for-byte the same chain as the nebula ssh-ng path.
            User = "remotebuild";
            Group = "remotebuild";
            # RNS wants a writable config dir in $HOME (remotebuild's is /var/empty)
            RuntimeDirectory = "rnsh-nix";
            Environment = "HOME=/run/rnsh-nix";
            # audit F6 (narrowed on purpose): no ProtectSystem/RestrictNamespaces/
            # PrivateTmp — the served nix-daemon writes /nix, needs build
            # namespaces and binds host /tmp for its sandbox.
            NoNewPrivileges = true;
            PrivateDevices = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectKernelLogs = true;
            ProtectClock = true;
            ProtectHostname = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            LockPersonality = true;
            RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
            SystemCallArchitectures = "native";
            # own writable rnsconfig: RNS creates storage/ here; the fleet
            # config is symlinked in by the root ExecStartPre below
            ExecStartPre = "+${
              pkgs.writeShellScript "rnsh-nix-rnsconfig" ''
                ${pkgs.coreutils}/bin/ln -sfn /run/reticulum/config /run/rnsh-nix/config
              ''
            }";
          };
          script = ''
            expected=${constants.reticulum.identities.${host}.nix}
            actual=$(${rnspython}/bin/rnid --config /run/rnsh-nix -i /run/reticulum/identity -H rnsh 2>/dev/null | ${pkgs.gnugrep}/bin/grep 'rnsh destination' | ${pkgs.gnugrep}/bin/grep -oE '[0-9a-f]{32}' || true)
            if [ "$actual" != "$expected" ]; then
              echo "rnsh-nix: destination hash mismatch: expected $expected, got '$actual'" >&2
              exit 1
            fi
            exec ${rnsh}/bin/rnsh --rnsconfig /run/rnsh-nix -l -b 900 -C -i /run/reticulum/identity \
              ${allowedIdentities} \
              -- ${config.nix.package}/bin/nix-daemon --stdio
          '';
        };
      };
    };
}
