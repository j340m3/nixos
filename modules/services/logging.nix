{ inputs, ... }:
let
  constants = import ../global/_constants.nix;
in
{
  flake.modules.nixos.logging =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {

      environment.systemPackages = with pkgs; [
        rsyslog
      ];

      # RAM-only journal: the log host (woody) is the sole durable copy. The
      # forwarder below is single-path TCP with a bounded disk queue.
      services.journald.settings.Journal = {
        Storage = "volatile";
        RuntimeMaxUse = "64M";
        # upstream default is "yes"; without this both imjournal and the syslog
        # socket deliver the same entry -> duplicates on the log host.
        ForwardToSyslog = false;
      };
      # stale persistent journals from before this switch must not linger
      systemd.tmpfiles.rules = [ "R /var/log/journal" ];
      services.rsyslogd = {
        enable = true;
        /*
          defaultConfig = ''
          		# Enable remote logging over UDP
          		$ModLoad imudp
          		$UDPServerRun 514
          		# Forward all logs to a remote server
          		*.* @10.0.0.3:514
          		'';
        */
        defaultConfig = ''
          			$PreserveFQDN on
          			$LocalHostName ${config.networking.hostName}
          			module(load="imjournal"             # provides access to the systemd journal
          					UsePid="system" # PID nummber is retrieved as the ID of the process the journal entry originates from
          					FileCreateMode="0644" # Set the access permissions for the state file
          					StateFile="imjournal.state"  # File to store the position in the journal
          					Ratelimit.Interval="300"     # Interval in seconds onto which rate-limiting is to be applied
          					Ratelimit.Burst="30000"      # Total number of messages allowed inside the interval
          					)
          			module(load="mmjsonparse")
          			module(load="imklog")

          			auth,authpriv.*                    /var/log/auth.log
          			local7.*                          -/var/log/boot.log
          			cron.*                             /var/log/cron.log
          			daemon.*                          -/var/log/daemon.log
          			kern.*                             /var/log/kern.log
          			user.*                            -/var/log/user.log
          			*.*;auth,authpriv.*                /var/log/syslog
          			'';
        extraConfig = ''
            			*.*  action(type="omfwd" target="${constants.host.woody.ip}" port="514" protocol="tcp"
            			action.resumeRetryCount="-1"
            			queue.type="linkedList" queue.size="10000" queue.dequeuebatchsize="1000"
            			queue.filename="qfwd" queue.maxFileSize="4m" queue.maxDiskSpace="32m"
            			queue.saveOnShutdown="on")
          	'';
      };

      services.logrotate.settings."/var/log/syslog" = {
        frequency = "hourly";
        rotate = 0;
        size = "100K";
        copytruncate = true;
      };

      services.logrotate.settings."/var/log/audit/audit.log" = {
        frequency = "hourly";
        rotate = 0;
        size = "100K";
        copytruncate = true;
      };

      services.logrotate.settings."/var/log/*.log" = {
        frequency = "hourly";
        rotate = 0;
        size = "100K";
        copytruncate = true;
      };
    };
}
