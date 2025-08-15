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
  device = "rsyslog:/rsyslog";
  fsType = "rclone";
  options = [
    "nodev"
    "_netdev"
    #"nofail"
    "noauto"
    "allow_other"
    "args2env"
    "x-systemd.automount"
    "cache_dir=/var/cache/rclone"
    "dir-cache-time=24h"
    "poll-interval=4h"
    "vfs-cache-mode=full"
    "vfs-cache-min-free-space=10G"
    "vfs-fast-fingerprint"
    "vfs-write-back=2h" # write changes after one hour
    "tpslimit=8"
    "tpslimit-burst=16"
    "config=/etc/rclone-mnt.conf"
    "x-systemd.after=network-online.target" # only after network came up
    #"uid=${toString config.users.users.immich.uid}"
    #"gid=${config.users.users.immich.group}"
  ];
  };
}