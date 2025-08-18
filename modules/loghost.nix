{
  config,
  lib,
  pkgs,
  ...
} : {
  environment.systemPackages = with pkgs; [
    rsyslog
  ];
  networking.firewall.interfaces."nebula.mesh".allowedUDPPorts = [ 514 ];
  services.journald.extraConfig = ''
		MaxRetentionSec=1week
		ForwardToSyslog=yes
	'';
  services.rsyslogd = {
		enable = true;
		defaultConfig = ''
        #module(load="imtcp")
        #input(type="imtcp" port="514")

        module(load="imudp")
        input(type="imudp" port="514")
        $PreserveFQDN on
        $LocalHostName ${config.networking.hostName}

        $template RemoteLogs,"/persist/rsyslog/%HOSTNAME%/%PROGRAMNAME%.log"
        #$template RemoteLogs,"/persist/rsyslog/%FROMHOST-IP%/%PROGRAMNAME%.log"
        ?RemoteLogs

        $template RemoteLogs2,"/persist/rsyslog/%HOSTNAME%/messages.log"
        #$template RemoteLogs2,"/persist/rsyslog/%FROMHOST-IP%/messages.log"
        ?RemoteLogs2
      '';
	};
  services.logrotate.settings."/persist/rsyslog/*/*.log" = {
		frequency = "weekly";
		rotate = 8;
    compress = true;
		copytruncate = true;
    olddir = "/mnt/nas/rsyslog";
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
    "vfs-write-back=1m" # write changes after one hour
    "vfs-cache-max-age=24h"                    # Retain cached files for up to 24 hours
    "vfs-read-chunk-size=32M"                  # Start with 32MB chunks for faster initial reads
    "vfs-read-chunk-size-limit=1G"             # Allow chunk size to grow up to 1GB for large files
    "vfs-cache-poll-interval=30s" 
    "tpslimit=8"
    "tpslimit-burst=16"
    "bwlimit=1K"
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
}