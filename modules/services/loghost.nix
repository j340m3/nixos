{ inputs, ... }:
let
  constants = import ../global/_constants.nix;
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
      mesh.openInbound = [
        {
          port = 514;
          proto = "tcp";
        }
        {
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

      fileSystems."/mnt/nas/rsyslog" = inputs.self.lib.rcloneMount {
        device = "rsyslog:rsyslog";
        sftpPath = "/volume1/borgbackup/rsyslog";
        configPath = "/etc/rclone-mnt.conf";
        options = [
          #"_netdev"
          #"nofail"
          "vfs-write-back=1m" # write changes after one minute
          "tpslimit=8"
          "tpslimit-burst=16"
          "bwlimit=10M"
          "transfers=4"
          "log-file=/var/log/rclone/rsyslog.log"
          #"uid=${toString config.users.users.immich.uid}"
          #"gid=${config.users.users.immich.group}"
        ];
      };
    };
}
