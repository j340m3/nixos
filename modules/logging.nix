{
  config,
  lib,
  pkgs,
  ...
} : {

	environment.systemPackages = with pkgs; [
		rsyslog
	];
	services.journald.extraConfig = ''
		Storage=none
		ForwardToSyslog=yes
	'';
	services.rsyslogd = {
		enable = true;
		defaultConfig = ''
		# Enable remote logging over UDP
		$ModLoad imudp
		$UDPServerRun 514
		# Forward all logs to a remote server
		*.* @10.0.0.3:514
		''
		/* defaultConfig = ''

			auth,authpriv.*                    /var/log/auth.log
			local7.*                          -/var/log/boot.log
			cron.*                             /var/log/cron.log
			daemon.*                          -/var/log/daemon.log
			kern.*                             /var/log/kern.log
			user.*                            -/var/log/user.log
			*.*;auth,authpriv.*               -/var/log/syslog
		''; */
	/* extraConfig = ''
		*.*  action(type="omfwd" target="10.0.0.3" port="514" protocol="udp"
			action.resumeRetryCount="100"
			queue.type="linkedList" queue.size="10000")
			*.* @10.0.0.3:514
	''; */
	};
}