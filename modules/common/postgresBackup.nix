{pkgs, config, ...}:{

  services.postgresqlBackup = {
    enable = true;
    location = "/mnt/filen/services/postgres/backups/${config.networking.hostName}";
  };

  # Skipped because detected autofs mount point
  #systemd.tmpfiles.rules = [
  #  "d /mnt/filen/services/postgres/backups 1750 postgres postgres -"
  #  "d /mnt/filen/services/postgres/backups/${config.networking.hostName} 1750 postgres postgres -"
  #];

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

  fileSystems."/mnt/filen/services/postgres" = {
    device = "filen:services/postgres";
    fsType = "rclone";
    options = [
      "nodev"
      #"_netdev"
      #"nofail"
      "noauto"
      "allow_other"
      "args2env"
      "x-systemd.automount"
      "cache_dir=/var/cache/rclone"
      #"dir-cache-time=24h"
      "vfs-cache-mode=full"
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
      "config=${config.sops.secrets."filen/postgres.conf".path}"
      "x-systemd.requires=network-online.target"
      "x-systemd.after=network-online.target" # only after network came up
      "uid=${toString config.users.users.postgres.uid}"
      "gid=${toString config.users.groups.postgres.gid}"
      "dir-perms=0770"
    ];
  };
}
