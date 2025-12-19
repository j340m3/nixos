{ config, pkgs, lib, ... }:

{
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
        SERVER_PORT_V6=19133;
        #OPS = "2535414708374553,2535448442672198"
        #ALLOW_LIST_USERS = "adyxax:2535470760215402,pseudo2:XXXXXXX,pseudo3:YYYYYYY";
      };
      image = "itzg/minecraft-bedrock-server";
      #ports = ["19132:19132/udp" "[::]:19132:19132/udp"];
      ports = ["19132:19132/udp" "[::]:19133:19133/udp"];
      volumes = [ "/nix/persist/minecraft/klassenserver/:/data" ];
    };
    /* emeliebjorn = {
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
    }; */
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
      ExecStart = lib.getExe (pkgs.writeShellScriptBin "update-containers" ''
        images=$(${pkgs.podman}/bin/podman ps -a --format="{{.Image}}" | sort -u)

        for image in $images; do
          ${pkgs.podman}/bin/podman pull "$image"
        done
      '');
    };
  };

  system.autoUpgrade = {
      rebootWindow = {
        lower = "03:00";
      };
    };
  
  sops.secrets."borg/minecraft-bedrock" = {
    sopsFile = ../secrets/${config.networking.hostName}/secrets.yaml;
  };

  services.borgbackup.jobs.minecraft-bedrock = {
    paths = ["/nix/persist/minecraft/klassenserver" "/nix/persist/minecraft/emeliebjorn"];
    encryption.mode = "none";
    environment.BORG_RSH = "ssh -i ${config.sops.secrets."borg/minecraft-bedrock".path}";
    repo = "borg@10.0.0.3:.";
    compression = "auto,lzma";
    startAt = "*-*-* 02:30:00";
    preHook = "${pkgs.podman}/bin/podman stop --all";
    postHook = "${pkgs.podman}/bin/podman start --all";
  };

  # Send an email whenever auto upgrade fails
    systemd.services."borgbackup-job-minecraft-bedrock".onFailure =
      lib.mkIf config.systemd.services."notify-telegram@".enable
      [ "notify-telegram@%i.service" ];
}
