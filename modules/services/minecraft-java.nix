{ inputs, ... }:
{
  flake.modules.nixos.minecraft-java =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ inputs.nix-minecraft.nixosModules.minecraft-servers ];
      nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

      services.minecraft-servers = {
        enable = true;
        eula = true;
        openFirewall = true;
        dataDir = "/nix/persist/minecraft";
        servers.java = {
          enable = true;
          package = pkgs.paperServers.paper;
          # 1-core/1.8GB host shared with the bedrock container: fixed 1G heap so
          # the JVM grows into swap instead of starving everything else, plus the
          # Aikar G1 flag set tuned for a small heap.
          # one line: the generated start script interpolates jvmOpts unquoted, so
          # embedded newlines would split it into separate shell commands.
          jvmOpts = "-Xms1024M -Xmx1024M -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 --add-modules=jdk.incubator.vector";
          serverProperties = {
            gamemode = 1;
            difficulty = 3;
            max-players = 5;
            motd = "NixOS Minecraft server!";
            white-list = true;
            # 1 core: cut render/simulation range instead of player cap
            view-distance = 6;
            simulation-distance = 4;
          };
        };
      };

      # Throttle the game into its own MemoryHigh before the host feels pressure,
      # and if OOM ever fires, java dies first — not bedrock or the OS.
      systemd.services."minecraft-server-java".serviceConfig = {
        MemoryHigh = "1500M";
        OOMScoreAdjust = 500;
      };

      # Ride along on the existing bedrock borg job: back the java world up and
      # stop/start it around the backup like the container is.
      services.borgbackup.jobs.minecraft-bedrock = {
        paths = [ "/nix/persist/minecraft/java" ];
        preHook = lib.mkBefore "systemctl stop minecraft-server-java.service";
        postHook = lib.mkAfter "systemctl start minecraft-server-java.service";
      };
    };
}
