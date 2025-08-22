{
  config,
  pkgs,
  lib,
  ...
}:
{
  environment.etc."paperless-admin-pass".text = "admin";
  services.paperless = {
    enable = true;
    passwordFile = "/etc/paperless-admin-pass";
    configureTika = true;
    database.createLocally = true;
    dataDir = "/mnt/nas/paperless";
    port = 28981;
    settings = {
      PAPERLESS_TASK_WORKERS = 1;
      PAPERLESS_THREADS_PER_WORKER = 2;
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      # # PAPERLESS_APP_TITLE = "paperless.chungus.private";
      # PAPERLESS_CONSUMER_IGNORE_PATTERN = builtins.toJSON [
      #   ".DS_STORE/*"
      #   "desktop.ini"
      # ];
      # PAPERLESS_EMAIL_TASK_CRON = "0 */8 * * *"; # “At minute 0 past every 8th hour.”

      # # https://github.com/paperless-ngx/paperless-ngx/discussions/4047#discussioncomment-7019544
      # # https://github.com/paperless-ngx/paperless-ngx/issues/7383
      # PAPERLESS_OCR_USER_ARGS = {
      #   "invalidate_digital_signatures" = true;
      # };  
    };
  };

  networking.firewall.interfaces."nebula.mesh".allowedTCPPorts = [ 28981 ];
  networking.firewall.allowedTCPPorts = [ 28981 ];

  users.users.paperless = {
    uid = 315;
    group = "paperless";
    #home = "/mnt/nas/immich";
    #createHome = true;
  }; 

  fileSystems."/mnt/nas/paperless" = {
  device = "paperless:paperless";
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
    "sftp-path-override=/volume1/borgbackup/paperless"
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
    "log-file=/var/log/rclone/paperless.log"
    "config=/etc/rclone-mnt.conf"
    "x-systemd.requires=network-online.target"
    "x-systemd.after=network-online.target" # only after network came up
    "uid=${toString config.users.users.paperless.uid}"
    "gid=${config.users.users.paperless.group}"
  ];
  };
}