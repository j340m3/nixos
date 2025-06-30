{ config, pkgs, lib, ... }:

{
   nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      # Add additional package names here
      "minecraft-server"
    ];
         

  services.minecraft-server = {
  enable = true;
  eula = true;
  openFirewall = true; # Opens the port the server is running on (by default 25565 but in this case 43000)
  declarative = true;
  serverProperties = {
    difficulty = 3;
    gamemode = 0;
    max-players = 10;
    motd = "NixOS Minecraft server!";
    #white-list = true;
    view-distance = 16;
  };
  dataDir = "/nix/persist/minecraft/java";
  #jvmOpts = "-Xms4092M -Xmx4092M -XX:+UseG1GC -XX:+CMSIncrementalPacing -XX:+CMSClassUnloadingEnabled -XX:ParallelGCThreads=2 -XX:MinHeapFreeRatio=5 -XX:MaxHeapFreeRatio=10";
};
}