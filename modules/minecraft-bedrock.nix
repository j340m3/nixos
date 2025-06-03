{ config, pkgs, lib, ... }:

{
  virtualisation.containers.enable = true;
  virtualisation.podman.enable = true;
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
        #OPS = "2535414708374553,2535448442672198"
        #ALLOW_LIST_USERS = "adyxax:2535470760215402,pseudo2:XXXXXXX,pseudo3:YYYYYYY";
      };
      image = "itzg/minecraft-bedrock-server";
      ports = ["19132:19132/udp" "[::]:19132:19132/udp"];
      volumes = [ "/nix/persist/minecraft/klassenserver/:/data" ];
    };
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
  };
  networking.firewall.allowedUDPPorts = [
    #53 # DNS
    19132 # Klassenserver
    19133 # emelie bjorn
  ];
}