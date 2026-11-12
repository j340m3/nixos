# rclone FUSE mount factory: the option base shared by every fleet rclone
# mount (NAS/SFTP mounts on woody + the filen mounts on nextcloud, postgres
# backup and the jeromeb user aspect), plus a family block for the SFTP/NAS
# mounts (`sftpPath` set). Consumers pass their per-mount deltas as
# `options`, appended verbatim — commented-out option strings travel with
# the deltas where they document tried-and-rejected values.
#
# The rendered Options= set is unchanged by this dedupe; only the order
# inside the option list moves (mount options are order-independent).
{ inputs, lib, ... }: {
  flake.lib.rcloneMount =
    {
      device, # remote:path passed to rclone, e.g. "immich:immich"
      configPath, # value of config= (rclone connection profile)
      sftpPath ? null, # set for the NAS/SFTP family; adds their tuning block
      uid ? null, # FUSE uid (toString'd); null for root mounts
      gid ? null, # FUSE gid, inserted verbatim (group name or numeric)
      options ? [ ],
    }:
    {
      inherit device;
      fsType = "rclone";
      options =
        [
          "nodev"
          "allow_other"
          "args2env"
          "cache_dir=/var/cache/rclone"
          "vfs-cache-mode=full"
          "x-systemd.requires=network-online.target"
          "x-systemd.after=network-online.target"
        ]
        ++ lib.optionals (sftpPath != null) [
          "noauto"
          "x-systemd.automount"
          "dir-cache-time=24h"
          "sftp-path-override=${sftpPath}"
          "vfs-fast-fingerprint"
          "vfs-cache-min-free-space=10G"
          "vfs-cache-max-age=24h"
          "vfs-read-chunk-size=32M"
          "vfs-read-chunk-size-limit=1G"
          "vfs-cache-poll-interval=30s"
          "log-level=INFO"
        ]
        ++ [ "config=${configPath}" ]
        ++ lib.optionals (uid != null) [
          "uid=${toString uid}"
          "gid=${gid}"
        ]
        ++ options;
    };
}
