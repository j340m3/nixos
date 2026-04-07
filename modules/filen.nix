{config,...}:{
  

  fileSystems."/mnt/filen/users/jeromeb" = {
    device = "jeromeb:jeromeb";
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
      "dir-cache-time=24h"
      #"sftp-path-override=/volume1/borgbackup/paperless"
      "vfs-cache-mode=full"
      "vfs-cache-min-free-space=10G"
      "vfs-fast-fingerprint"
      "vfs-write-back=1m" # write changes after one hour
      "vfs-cache-max-age=24h"                    # Retain cached files for up to 24 hours
      "vfs-read-chunk-size=32M"                  # Start with 32MB chunks for faster initial reads
      "vfs-read-chunk-size-limit=1G"             # Allow chunk size to grow up to 1GB for large files
      "vfs-cache-poll-interval=30s" 
      "tpslimit=16"
      "tpslimit-burst=32"
      "log-level=INFO"
      "log-file=/var/log/rclone/users/jeromeb.log"
      "config=/etc/rclone-mnt.conf"
      "x-systemd.requires=network-online.target"
      "x-systemd.after=network-online.target" # only after network came up
      "uid=${toString config.users.users.jeromeb.uid}"
      "gid=${config.users.users.jeromeb.group}"
    ];
  };
}
