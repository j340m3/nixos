# dendritic aspect (ADR 0018): artifact-first updates for memory-starved
# hosts. The host no longer evaluates the flake itself on the happy path: a
# publisher (woody, artifact-publisher aspect) builds the system closures,
# serves a small manifest over the mesh, and this aspect substitutes the
# closure (signature-checked against the harmonia key in the fleet
# substituters) and switches to it.
#
# ADR 0000 independence: every failure — manifest unreachable, malformed
# entry, substitution failure — falls back to the unchanged
# system.autoUpgrade path (nixos-upgrade.service), which evaluates and
# builds locally exactly as before. The artifact path is an accelerator,
# never a requirement.
{ inputs, ... }:
let
  constants = import ../global/_constants.nix;
in
{
  flake.modules.nixos.artifact-update =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.artifactUpdate;
    in
    {
      options.artifactUpdate = {
        enable = lib.mkEnableOption ''
          artifact-first updates: poll the publisher's manifest, substitute the
          prebuilt system closure and switch to it, falling back to the local
          nixos-upgrade evaluation on any failure.
        '';
        manifestUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://${constants.host.woody.ip}:5001/manifest.json";
          description = ''
            Where the publisher serves the manifest. Mesh-internal HTTP on
            purpose: the content carries no trust (store paths only), and the
            actual safety boundary is the nix signature check on the closure.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        # The artifact path replaces the hourly *timer*, not the unit: the
        # nixos-upgrade unit stays as the failure fallback, triggered by this
        # service's OnFailure.
        systemd.timers.nixos-upgrade.enable = lib.mkForce false;

        systemd.services.artifact-update = {
          description = "Artifact-first update: substitute the publisher-built system closure and switch to it";
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          # never concurrent with the eval fallback (or with itself across a
          # slow switch + retry)
          conflicts = [ "nixos-upgrade.service" ];
          # loud failure (repo convention) + the local-eval fallback
          onFailure = [
            "notify-telegram@%i.service"
            "nixos-upgrade.service"
          ];
          # the health check normally rides on nixos-upgrade.onSuccess
          # (upgrade-health.nix); the artifact path must arm it too, so a
          # broken artifact switch rolls back like a rebuild switch would.
          onSuccess = lib.mkIf config.upgradeHealth.enable [ "nixos-upgrade-health-schedule.service" ];
          serviceConfig.Type = "oneshot";
          script =
            let
              jq = "${pkgs.jq}/bin/jq";
              curl = "${pkgs.curl}/bin/curl";
              nix-store = "${config.nix.package}/bin/nix-store";
              nix-env = "${config.nix.package}/bin/nix-env";
            in
            ''
              set -euo pipefail
              host=${config.networking.hostName}
              state=/var/lib/artifact-update
              ${pkgs.coreutils}/bin/install -d -m 0755 "$state"

              if ! manifest=$(${curl} -fsS --max-time 30 ${lib.escapeShellArg cfg.manifestUrl}); then
                echo "artifact-update: manifest unreachable, falling back"
                exit 1
              fi

              wanted=$(printf '%s' "$manifest" | ${jq} -er --arg h "$host" '.[$h].system') \
                || { echo "artifact-update: no system entry for $host, falling back"; exit 1; }
              case "$wanted" in
                /nix/store/*-nixos-system-*) ;;
                *) echo "artifact-update: entry for $host is not a system closure path: $wanted, falling back"; exit 1 ;;
              esac

              # at-most-once per distinct closure (ADR 0018): a path already
              # applied once is never applied again, so a stale manifest can
              # neither clobber a manual rebuild nor loop, and a downgrade
              # would need the state file to vanish AND the publisher to serve
              # an older closure.
              applied="$state/last-applied"
              if [ -f "$applied" ] && [ "$wanted" = "$(cat "$applied")" ]; then
                echo "artifact-update: $wanted already applied once, nothing to do"
                exit 0
              fi
              current=$(readlink -f /run/current-system)
              if [ "$wanted" = "$current" ]; then
                echo "$wanted" > "$applied"
                echo "artifact-update: already running $wanted"
                exit 0
              fi

              echo "artifact-update: substituting $wanted"
              ${nix-store} -r "$wanted" >/dev/null
              if [ ! -x "$wanted/bin/switch-to-configuration" ]; then
                echo "artifact-update: $wanted has no switch-to-configuration, falling back"
                exit 1
              fi

              # profile first, then switch: same order nixos-rebuild uses, so
              # switch-to-configuration's view of the system profile matches.
              ${nix-env} -p /nix/var/nix/profiles/system --set "$wanted"
              "$wanted/bin/switch-to-configuration" switch
              echo "$wanted" > "$applied"
              echo "artifact-update: switched to $wanted"
            '';
        };

        # :05 + jitter, well ahead of the :45 nixos-upgrade window the
        # fallback would have used anyway — and the fallback fires
        # immediately on failure, not on that schedule.
        systemd.timers.artifact-update = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*-*-* 0/1:05:00";
            RandomizedDelaySec = "25min";
            Persistent = true;
          };
        };
      };
    };
}
