{
  config,
  lib,
  pkgs,
  ...
} : {
  services.nebula.networks.mesh.firewall.inbound = [
    {
      host = "any";
      port = "514";
      proto = "UDP";
    }
  ];
  services.journald.extraConfig = ''
		Storage=none
		ForwardToSyslog=yes
	'';
  services.rsyslogd = {
		enable = true;
		defaultConfig = ''
        module(load="imtcp")
        input(type="imtcp" port="514")

        module(load="imudp")
        input(type="imudp" port="514")

        $template RemoteLogs,"/persist/rsyslog/%HOSTNAME%/%PROGRAMNAME%.log"
        ?RemoteLogs

        $template RemoteLogs2,"/persist/rsyslog/%HOSTNAME%/messages.log"
        ?RemoteLogs2
      '';
	};
  
}