{ inputs, ... }: {
  flake.modules.nixos.postgres-backup =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {

      services.postgresqlBackup = {
        enable = true;
        location = "/mnt/filen/services/postgres/backups/${config.networking.hostName}";
      };

      # rclone refuses to mount when it cannot open its own log file
      # ("Failed to open log file: open /var/log/rclone/filen/postgres.log").
      systemd.tmpfiles.rules = [
        "d /var/log/rclone/filen 0750 root root -"
      ];

      sops.secrets."filen/postgres.conf" = {
        format = "ini";
        sopsFile = ../../secrets/services/postgres/rclone.ini;
        #restartUnits = ["nebula@mesh.service"];
        owner = "postgres";
        group = "postgres";
        #path = "/etc/nebula/self.key";
        key = "";
      };

      environment.systemPackages = with pkgs; [
        rclone
      ];

      fileSystems."/mnt/filen/services/postgres" = inputs.self.lib.rcloneMount {
        device = "filen:services/postgres";
        configPath = config.sops.secrets."filen/postgres.conf".path;
        uid = config.users.users.postgres.uid;
        gid = toString config.users.groups.postgres.gid;
        options = [
          #"_netdev"
          #"nofail"
          "noauto"
          "x-systemd.automount"
          #"dir-cache-time=24h"
          "vfs-cache-min-free-space=2G"
          "vfs-fast-fingerprint"
          "vfs-links"
          "transfers=16"
          "vfs-write-back=1h" # write changes after one hour
          "vfs-cache-max-age=24h" # Retain cached files for up to 24 hours
          "vfs-read-chunk-size=32M" # Start with 32MB chunks for faster initial reads
          "vfs-read-chunk-size-limit=1G" # Allow chunk size to grow up to 1GB for large files
          #"vfs-cache-poll-interval=30s"
          "tpslimit=16"
          "tpslimit-burst=32"
          "log-level=INFO"
          "log-file=/var/log/rclone/filen/postgres.log"
          "dir-perms=0770"
        ];
      };
    };
}
