{}:{virtualisation.oci-containers.containers = {
    minecraft = {
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
      ports = ["0.0.0.0:19132:19132/udp"];
      volumes = [ "/nix/persist/minecraft/:/data" ];
    };
  };
}