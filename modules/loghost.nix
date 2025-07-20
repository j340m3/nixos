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

        $template RemoteLogs,"/mnt/nas/rsyslog/%HOSTNAME%/%PROGRAMNAME%.log"
        #$template RemoteLogs,"/mnt/nas/rsyslog/%FROMHOST-IP%/%PROGRAMNAME%.log"
        ?RemoteLogs

        $template RemoteLogs2,"/mnt/nas/rsyslog/%HOSTNAME%/messages.log"
        #$template RemoteLogs2,"/mnt/nas/rsyslog/%FROMHOST-IP%/messages.log"
        ?RemoteLogs2
      '';
	};
  services.logrotate.settings."/mnt/nas/rsyslog/*/*.log" = {
		frequency = "weekly";
		rotate = 8;
    compress = true;
		copytruncate = true;
	}; 

  fileSystems."/mnt/nas/rsyslog" = {
  device = "bergmannnas.fritz.box:/rsyslog";
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
    "vfs-cache-mode=full"
    "vfs-cache-min-free-space=10G"
    "config=/etc/rclone-mnt.conf"
    #"uid=${toString config.users.users.immich.uid}"
    #"gid=${config.users.users.immich.group}"
  ];
  };
}