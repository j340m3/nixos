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
		Storage=none
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
	}; 
}