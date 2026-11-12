{ inputs, ... }:
let
  constants = import ../global/_constants.nix;
in
{
  flake.modules.nixos.minecraft-bedrock =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      imports = [
        # the repo lives on woody's borg-server (modules/services/borg-server.nix)
        (inputs.self.lib.borgClientJob {
          name = "minecraft-bedrock";
          paths = [
            "/nix/persist/minecraft/klassenserver"
            "/nix/persist/minecraft/emeliebjorn"
          ];
          repo = "borg@${constants.host.woody.ip}:.";
          secretFile = ../../secrets/hosts/${config.networking.hostName}/secrets.yaml;
          startAt = "*-*-* 02:30:00";
          extra = {
            # hooks must not abort the job: each failure previously failed the
            # whole backup and paged the telegram bot for backups that succeeded
            # without the stop/start choreography.
            preHook = ''
              ${pkgs.podman}/bin/podman stop --all 2>&1 ||
                echo "borg preHook: podman stop failed; backing up as-is"
            '';
            postHook = ''
              ${pkgs.podman}/bin/podman start --all 2>&1 ||
                echo "borg postHook: podman start failed; containers need manual start"
            '';
          };
        })
      ];

      virtualisation.containers.enable = true;
      virtualisation.podman = {
        enable = true;
        autoPrune = {
          enable = true;
          flags = [ "--all" ];
        };
      };
      virtualisation.oci-containers.backend = "podman";
      virtualisation.oci-containers.containers = {
        klassenserver = {
          environment = {
            ALLOW_CHEATS = "true";
            EULA = "TRUE";
            DIFFICULTY = "1";
            SERVER_NAME = "Klassenserver";
            LEVEL_NAME = "Klassenserver";
            TZ = "Europe/Berlin";
            VERSION = "LATEST";
            KEEP_INVENTORY = "true";
            #SERVER_PORT_V6="19133";
            #OPS = "2535414708374553,2535448442672198"
            #ALLOW_LIST_USERS = "adyxax:2535470760215402,pseudo2:XXXXXXX,pseudo3:YYYYYYY";
          };
          image = "docker.io/itzg/minecraft-bedrock-server";
          ports = [
            "19132:19132/udp"
            "[::]:19132:19132/udp"
          ];
          #ports = ["19132:19132/udp" "[::]:19133:19133/udp"];
          volumes = [ "/nix/persist/minecraft/klassenserver/:/data" ];
        };
        /*
          emeliebjorn = {
            environment = {
              ALLOW_CHEATS = "true";
              EULA = "TRUE";
              DIFFICULTY = "1";
              SERVER_NAME = "Emelie Bjorn";
              LEVEL_NAME = "Emelie Bjorn";
              TZ = "Europe/Berlin";
              VERSION = "LATEST";
              #KEEP_INVENTORY = "true";

              #ALLOW_LIST_USERS = "adyxax:2535470760215402,pseudo2:XXXXXXX,pseudo3:YYYYYYY";
            };
            image = "itzg/minecraft-bedrock-server";
            ports = ["19133:19132/udp"];
            volumes = [ "/nix/persist/minecraft/emeliebjorn/:/data" ];
          };
        */
      };
      networking.firewall.allowedUDPPorts = [
        #53 # DNS
        19132 # Klassenserver
        19133 # Klassenserver v6
      ];

      systemd.timers.update-containers = {
        timerConfig = {
          Unit = "update-containers.service";
          OnCalendar = "*-*-* 02:00:00";
        };
        wantedBy = [ "timers.target" ];
      };

      systemd.services.update-containers = {
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe (
            pkgs.writeShellScriptBin "update-containers" ''
              images=$(${pkgs.podman}/bin/podman ps -a --format="{{.Image}}" | sort -u)

              for image in $images; do
                # a failed image refresh must not fail this unit: a failed unit makes
                # nixos-upgrade-health roll the host back a whole OS generation over
                # a container tag that did not resolve this once.
                ${pkgs.podman}/bin/podman pull "$image" ||
                  echo "update-containers: pull failed for $image"
              done
            ''
          );
        };
      };

      system.autoUpgrade = {
        rebootWindow = {
          lower = "03:00";
        };
      };

      # the borgbackup module locks the job unit down (ProtectSystem=strict,
      # ReadWritePaths only its own borg cache/config dirs), so a preHook
      # `podman stop --all` fails with EROFS on the storage and netavark
      # locks and originally aborted the job. open the podman storage dir
      # and /run/lock for the job.
      systemd.services."borgbackup-job-minecraft-bedrock".serviceConfig.ReadWritePaths = [
        "/var/lib/containers"
        "/run/lock"
      ];
    };
}
