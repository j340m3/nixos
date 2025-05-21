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
        TZ = "Europe/Berlin";
        VERSION = "LATEST";
        #ALLOW_LIST_USERS = "adyxax:2535470760215402,pseudo2:XXXXXXX,pseudo3:YYYYYYY";
      };
      image = "itzg/minecraft-bedrock-server";
      ports = ["19132:19132/udp"];
      volumes = [ "/nix/persist/minecraft/klassenserver/:/data" ];
    };
    emeliebjorn = {
      environment = {
        ALLOW_CHEATS = "true";
        EULA = "TRUE";
        DIFFICULTY = "1";
        SERVER_NAME = "Emelie Bjorn";
        TZ = "Europe/Berlin";
        VERSION = "LATEST";
        #ALLOW_LIST_USERS = "adyxax:2535470760215402,pseudo2:XXXXXXX,pseudo3:YYYYYYY";
      };
      image = "itzg/minecraft-bedrock-server";
      ports = ["19132:19133/udp"];
      volumes = [ "/nix/persist/minecraft/emeliebjorn/:/data" ];
    };
  };
  networking.firewall.allowedUDPPorts = [
    #53 # DNS
    19132 # Minecraft
  ];
}