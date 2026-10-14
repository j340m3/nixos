application_name: application_service: user: group:
let
  rclone_service = "mnt-filen-services-${application_name}";
  path = "/mnt/filen/services/${application_name}/";
in
{
  systemd.services."${rclone_service}-tmpfiles-resetup" = {
    script = "systemd-tmpfiles --create --remove --prefix=${path}";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    after = [ "${rclone_service}.mount" ];
    requires = [ "${rclone_service}.mount" ];
    before = [ "${application_service}.service" ];
  };

  systemd.services.${application_service}.after = [
    "${rclone_service}.mount"
    "${rclone_service}-tmpfiles-resetup.service"
  ];
  systemd.services.${application_service}.requires = [
    "${rclone_service}.mount"
    "${rclone_service}-tmpfiles-resetup.service"
  ];

  sops.secrets."filen/${application_name}.conf" = {
    format = "ini";
    sopsFile = ../secrets/services/${application_name}/rclone.ini;
    #restartUnits = ["nebula@mesh.service"];
    owner = user.name;
    group = group.name;
    path = "/var/run/secrests/filen/${application_name}.conf";
    key = "";
  };

  fileSystems."/mnt/filen/services/nextcloud" = {
    device = "filen:services/nextcloud";
    fsType = "rclone";
    options = [
      "nodev"
      "_netdev"
      "nofail"
      #"auto"
      "allow_other"
      "args2env"
      #"x-systemd.automount"
      "cache_dir=/var/cache/rclone"
      #"dir-cache-time=24h"
      "allow-non-empty"
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
      "log-file=/var/log/rclone/filen/nextcloud.log"
      "config=/var/run/secrests/filen/${application_name}.conf"
      "x-systemd.requires=network-online.target"
      "x-systemd.after=network-online.target" # only after network came up
      "x-systemd.onSuccess=mnt-filen-services-nextcloud-tmpfiles-resetup.service"
      "uid=${toString user.uid}"
      "gid=${toString group.gid}"
      "dir-perms=0770"
    ];
  };

}
