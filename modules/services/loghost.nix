{ inputs, ... }:
let
  constants = import (inputs.self + "/global/constants.nix");
in
{
  flake.modules.nixos.loghost =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      rcloneLog = {
        size = "50M";
        rotate = 3;
        compress = true;
        copytruncate = true;
        missingok = true;
      };
    in
    {
      environment.systemPackages = with pkgs; [
        rsyslog
      ];
      networking.firewall.interfaces."nebula.mesh" = {
        allowedUDPPorts = [ 514 ]; # legacy clients until rebuilt; drop after migration
        allowedTCPPorts = [ 514 ];
      };
      # The host firewall above is not enough: nebula has its own in-tunnel
      # firewall, and remote hosts' TCP 514 connections were silently dropped.
      services.nebula.networks.mesh.firewall.inbound =
        lib.mkIf config.services.nebula.networks.mesh.enable
          [
            {
              cidr = constants.nebula.cidr;
              port = 514;
              proto = "tcp";
            }
            {
              cidr = constants.nebula.cidr;
              port = 514;
              proto = "udp";
            }
          ];
      services.journald.settings.Journal = {
        MaxRetentionSec = "1week";
        # imjournal is the single reader; ForwardToSyslog would also feed
        # imuxsock and duplicate woody's own messages.
        ForwardToSyslog = false;
      };
      services.rsyslogd = {
        enable = true;
        defaultConfig = ''
          # Read the journal directly. journald does not forward to syslog here,
          # so without this the loghost writes no local messages at all.
          module(load="imjournal"
            StateFile="imjournal.state"
            Ratelimit.Interval="300"
            Ratelimit.Burst="30000"
          )

          module(load="imtcp")
          input(type="imtcp" port="514")

          module(load="imudp")
            input(type="imudp" port="514")
            $PreserveFQDN on
            $LocalHostName ${config.networking.hostName}
            # rsyslog defaults to 0700, which masks the jeromeb ACL on new
            # per-host dirs (mrpotatohead's log dir became unreadable).
            $DirCreateMode 0750

            $template RemoteLogs,"/persist/rsyslog/%HOSTNAME%/%PROGRAMNAME%.log"
            #$template RemoteLogs,"/persist/rsyslog/%FROMHOST-IP%/%PROGRAMNAME%.log"
            ?RemoteLogs

            $template RemoteLogs2,"/persist/rsyslog/%HOSTNAME%/messages.log"
            #$template RemoteLogs2,"/persist/rsyslog/%FROMHOST-IP%/messages.log"
            ?RemoteLogs2
        '';
      };
      # One olddir per host; a shared olddir made every host overwrite the same
      # messages.log.N.gz on the NAS.
      services.logrotate.settings =
        lib.mapAttrs' (
          host: _:
          lib.nameValuePair "/persist/rsyslog/${host}/*.log" {
            frequency = "weekly";
            rotate = 8;
            compress = true;
            copytruncate = true;
            missingok = true;
            notifempty = true;
            olddir = "/mnt/nas/rsyslog/${host}";
            createolddir = "0755 root root";
          }
        ) constants.host
        // {
          "/var/log/rclone.log" = rcloneLog;
          "/var/log/rclone/*.log" = rcloneLog;
        };

      fileSystems."/mnt/nas/rsyslog" = {
        device = "rsyslog:rsyslog";
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
          "sftp-path-override=/volume1/borgbackup/rsyslog"
          "vfs-cache-mode=full"
          "vfs-cache-min-free-space=10G"
          "vfs-fast-fingerprint"
          "vfs-write-back=1m" # write changes after one minute
          "vfs-cache-max-age=24h" # Retain cached files for up to 24 hours
          "vfs-read-chunk-size=32M" # Start with 32MB chunks for faster initial reads
          "vfs-read-chunk-size-limit=1G" # Allow chunk size to grow up to 1GB for large files
          "vfs-cache-poll-interval=30s"
          "tpslimit=8"
          "tpslimit-burst=16"
          "bwlimit=10M"
          "transfers=4"
          "log-level=INFO"
          "log-file=/var/log/rclone/rsyslog.log"
          "config=/etc/rclone-mnt.conf"
          "x-systemd.requires=network-online.target"
          "x-systemd.after=network-online.target" # only after network came up
          #"uid=${toString config.users.users.immich.uid}"
          #"gid=${config.users.users.immich.group}"
        ];
      };
    };
}
