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
        autoReboot = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Reboot when the current system carries a kernel (or initrd) the
            running system predates, inside system.autoUpgrade.rebootWindow.
            Follow-up to ADR-0018 (2026-11-14): without this the artifact
            path stages a new kernel that only boots at the next manual
            reboot. Also gated by the fleet-wide allowReboot option.
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

        # ADR-0018 follow-up (2026-11-14): the upstream nixos-upgrade reboot
        # check never runs on the artifact path (its timer is forced off and
        # the unit only fires as fallback), so a kernel bump staged by a
        # successful switch would sit unbooted until a manual reboot. This
        # check reboots when booted kernel/initrd differ from the current
        # system's — the same comparison the fallback path makes — but only
        # inside the same rebootWindow (22:00–08:00), reused, not duplicated,
        # and only for changes staged DURING the current uptime
        # (artifact-update-boot-state records the baseline in /run, which is
        # tmpfs and therefore fresh every boot). That last bit is what keeps
        # a deliberate rollback respected: booting a previous boot entry
        # leaves the newer generation current, and the check must not
        # immediately bounce the host back into it — a kernel that was
        # already current at boot is never acted on. Manual rebuilds that
        # swap the kernel mid-uptime do trigger the windowed reboot, which
        # is the same policy the fallback path applies.
        systemd.services.artifact-update-boot-state = lib.mkIf (cfg.autoReboot && (config.allowReboot or true)) {
          description = "Artifact-first updates: record the kernel/initrd current at boot for the reboot check";
          after = [ "local-fs.target" ];
          wantedBy = [ "basic.target" ];
          serviceConfig.Type = "oneshot";
          # /run is tmpfs: the baseline written here dies with the uptime,
          # so a reboot — including a deliberate one into a previous boot
          # entry — always starts from a fresh, honest baseline.
          script =
            let
              install = "${pkgs.coreutils}/bin/install";
              readlink = "${pkgs.coreutils}/bin/readlink";
            in
            ''
              set -euo pipefail
              ${install} -d -m 0755 /run/artifact-update
              for part in kernel initrd; do
                if [ -e "/run/current-system/$part" ]; then
                  ${readlink} -f "/run/current-system/$part" > "/run/artifact-update/$part-at-boot"
                fi
              done
            '';
        };

        systemd.services.artifact-update-reboot = lib.mkIf (cfg.autoReboot && (config.allowReboot or true)) {
          description = "Artifact-first updates: reboot for a staged kernel, inside the reboot window";
          after = [ "time-sync.target" ];
          # serialize with the switcher: don't compare while it swaps
          # /run/current-system under us
          conflicts = [ "artifact-update.service" ];
          serviceConfig.Type = "oneshot";
          script =
            let
              date = "${pkgs.coreutils}/bin/date";
              readlink = "${pkgs.coreutils}/bin/readlink";
              systemctl = "${pkgs.systemd}/bin/systemctl";
              lower = config.system.autoUpgrade.rebootWindow.lower;
              upper = config.system.autoUpgrade.rebootWindow.upper;
            in
            ''
              set -euo pipefail
              booted=/run/booted-system
              current=/run/current-system
              if [ ! -e "$booted" ]; then
                echo "artifact-update-reboot: no booted-system yet, skipping"
                exit 0
              fi

              reboot=0
              for part in kernel initrd; do
                if [ -e "$booted/$part" ] && [ -e "$current/$part" ]; then
                  b=$(${readlink} -f "$booted/$part")
                  c=$(${readlink} -f "$current/$part")
                  if [ "$b" = "$c" ]; then
                    continue
                  fi
                  # uptime-aware (ADR-0018 follow-up, 2026-11-14): only
                  # reboot for changes staged during the current uptime.
                  # A part that was already current at boot (deliberate
                  # reboot into a previous boot entry, leaving a newer
                  # generation queued) is left alone; a missing baseline
                  # (marker unit hasn't run, e.g. booted an older
                  # generation) means we can't tell — skip, conservatively.
                  baseline="/run/artifact-update/$part-at-boot"
                  if [ ! -f "$baseline" ]; then
                    echo "artifact-update-reboot: no boot baseline for $part, skipping"
                    continue
                  fi
                  if [ "$(cat "$baseline")" = "$c" ]; then
                    echo "artifact-update-reboot: $part already current at boot ($c), not overriding the boot choice"
                    continue
                  fi
                  echo "artifact-update-reboot: $part staged during this uptime ($b -> $c)"
                  reboot=1
                fi
              done
              if [ "$reboot" != 1 ]; then
                exit 0
              fi

              # rebootWindow lower/upper as HH:MM; lexicographic compare is
              # correct for zero-padded HH:MM. A lower > upper window
              # crosses midnight (22:00–08:00).
              now=$(${date} +%H:%M)
              lower=${lib.escapeShellArg lower}
              upper=${lib.escapeShellArg upper}
              in_window=0
              if [ "$lower" "<" "$upper" ]; then
                if [ "$now" ">=" "$lower" ] && [ "$now" "<" "$upper" ]; then
                  in_window=1
                fi
              else
                if [ "$now" ">=" "$lower" ] || [ "$now" "<" "$upper" ]; then
                  in_window=1
                fi
              fi
              if [ "$in_window" != 1 ]; then
                echo "artifact-update-reboot: kernel staged, but $now is outside the reboot window ($lower–$upper), waiting"
                exit 0
              fi

              echo "artifact-update-reboot: rebooting into the staged kernel"
              ${systemctl} reboot
            '';
        };

        # Cheap local-only check, every quarter hour with jitter so a kernel
        # staged early in the window reboots within minutes of it opening.
        # Persistent = false on purpose: no catch-up reboot right after boot.
        systemd.timers.artifact-update-reboot = lib.mkIf (cfg.autoReboot && (config.allowReboot or true)) {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*:0/15";
            RandomizedDelaySec = "5min";
            Persistent = false;
          };
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
