# dendritic aspect (ADR 0018): the artifact-first publisher. Runs on a host
# with build headroom (woody) and pre-builds the system closures of hosts
# whose updates would otherwise cost them an eval + build under RAM
# pressure. The closures land in this host's /nix/store, which is exactly
# what the harmonia binary cache serves — building here *is* publishing;
# nothing ever pushes to the cache.
#
# ADR 0000 independence: a client with this service dark still updates
# itself via the plain nixos-upgrade path. This aspect is an accelerator.
{ inputs, ... }:
let
  constants = import ../global/_constants.nix;
in
{
  flake.modules.nixos.artifact-publisher =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.artifactPublisher;
      stateDir = "/var/lib/artifact-publisher";
      nixBin = "${config.nix.package}/bin/nix";
      jq = "${pkgs.jq}/bin/jq";
      hostsStr = lib.concatStringsSep " " cfg.hosts;
    in
    {
      options.artifactPublisher = {
        enable = lib.mkEnableOption ''
          pre-building other hosts' system closures and serving a manifest of
          them over the mesh, so artifact-first clients can substitute instead
          of evaluating.
        '';
        hosts = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Hosts whose system.build.toplevel is built each cycle.";
        };
        flakeRef = lib.mkOption {
          type = lib.types.str;
          default = "github:j340m3/nixos";
          # same reasoning as update.nix: an outPath would pin the snapshot
          # and fail forever once something broke
          description = "Flake the closures are built from.";
        };
        manifestPort = lib.mkOption {
          type = lib.types.port;
          default = 5001;
          description = ''
            Mesh-only nginx port serving the manifest (harmonia owns :5000's
            protocol; this only ships a static JSON file).
          '';
        };
        minFree = lib.mkOption {
          type = lib.types.str;
          default = "6G";
          description = ''
            Skip the cycle (loudly) when /nix has less than this free. Same
            philosophy as the upgrade-space-guard: a loud failure is the
            point, clients fall back to their own eval path meanwhile.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        services.nginx.enable = lib.mkDefault true;
        # Manifest served on the nebula address only: not reachable from the
        # internet, no TLS dance for a file whose content is untrusted store
        # paths anyway — the client's signature check is the safety boundary.
        services.nginx.virtualHosts."artifact-manifest" = {
          listen = [
            {
              addr = constants.host.woody.ip;
              port = cfg.manifestPort;
            }
          ];
          locations."= /manifest.json" = {
            alias = "${stateDir}/manifest.json";
            extraConfig = "default_type application/json;";
          };
        };
        # both gatekeeping layers (see harmonia.nix for the pattern)
        networking.firewall.interfaces."nebula.mesh".allowedTCPPorts = [
          cfg.manifestPort
        ];
        mesh.openInbound = [
          {
            port = cfg.manifestPort;
            proto = "tcp";
          }
        ];

        systemd.services.artifact-publisher = {
          description = "Artifact-first publisher: build client closures and refresh the manifest";
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          onFailure = [ "notify-telegram@%i.service" ];
          # build work itself runs under woody's nix-daemon (idle CPU/IO sched
          # via update.nix); this keeps the driver's eval + flake fetch polite
          serviceConfig = {
            Type = "oneshot";
            Nice = 10;
            IOSchedulingClass = "idle";
          };
          script = ''
            set -euo pipefail
            state=${stateDir}
            ${pkgs.coreutils}/bin/install -d -m 0755 "$state/roots"

            # space guard: publishing must not eat the room the host's own
            # upgrade-space-guard needs (woody's ~17G free baseline)
            free=$(${pkgs.coreutils}/bin/df --output=avail --block-size=1 /nix | ${pkgs.coreutils}/bin/tail -n1)
            min=$(${pkgs.coreutils}/bin/numfmt --from=iec ${lib.escapeShellArg cfg.minFree})
            if [ "$free" -lt "$min" ]; then
              echo "artifact-publisher: only $free bytes free (< ${cfg.minFree}), skipping publish cycle"
              exit 1
            fi

            rev=$(${nixBin} flake metadata --json ${lib.escapeShellArg cfg.flakeRef} | ${jq} -r .revision)

            failures=""
            for h in ${hostsStr}; do
              root="$state/roots/$h"
              # out-link under the state dir = indirect GC root. The link is
              # replaced each run, so only the latest closure per host stays
              # rooted; everything older is released to woody's hourly GC
              # (7d rule). On failure the link is left alone so the manifest
              # keeps serving the last good closure.
              if ! sys=$(${nixBin} build ${lib.escapeShellArg cfg.flakeRef}#nixosConfigurations.$h.config.system.build.toplevel \
                  --out-link "$root" --print-out-paths 2>"$state/build-$h.log"); then
                echo "artifact-publisher: building $h failed, last log lines:"
                ${pkgs.coreutils}/bin/tail -n 10 "$state/build-$h.log" || true
                failures="$failures $h"
                continue
              fi
              sys=$(printf '%s' "$sys" | ${pkgs.coreutils}/bin/head -n1)
              echo "artifact-publisher: $h -> $sys (rev $rev)"
            done

            # regenerate the manifest from the surviving out-links: they are
            # the source of truth, so a failed host keeps its last entry
            manifest='{}'
            for h in ${hostsStr}; do
              root="$state/roots/$h"
              if [ -e "$root" ]; then
                sys=$(readlink -f "$root")
                ts=$(${pkgs.coreutils}/bin/stat -c %Y "$sys")
                manifest=$(${jq} -c --arg h "$h" --arg sys "$sys" --arg rev "$rev" --argjson ts "$ts" \
                  '. + { ($h): { system: $sys, rev: $rev, built: $ts } }' <<<"$manifest")
              fi
            done
            ${jq} -S . <<<"$manifest" > "$state/manifest.json.new"
            ${pkgs.coreutils}/bin/mv "$state/manifest.json.new" "$state/manifest.json"
            ${pkgs.coreutils}/bin/chmod 0644 "$state/manifest.json"

            if [ -n "$failures" ]; then
              echo "artifact-publisher: failed hosts:$failures"
              exit 1
            fi
          '';
        };

        # :25 sits between the host GC (:15) and nixos-upgrade (:45), so the
        # space guard sees post-GC conditions and the publisher's builds do
        # not race the host's own upgrade eval.
        systemd.timers.artifact-publisher = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*-*-* 0/1:25:00";
            RandomizedDelaySec = "10min";
            Persistent = true;
          };
        };
      };
    };
}
