{ config, pkgs, inputs, lib,  ... }:

{
  options = {};
  config = {
    services.fail2ban = {
      enable = lib.mkDefault true;
      daemonSettings = {
        Definition = {
          logtarget = "SYSLOG";
          socket = "/run/fail2ban/fail2ban.sock";
          pidfile = "/run/fail2ban/fail2ban.pid";
          dbfile = "/var/lib/fail2ban/fail2ban.sqlite3";
        };
      };
    };
    /* security.pam.services = {
      login.googleAuthenticator.enable = true;
      # https://github.com/NixOS/nixpkgs/issues/115044#issuecomment-2065409087
      sshd.text = ''
          account required pam_unix.so # unix (order 10900)

          auth required ${pkgs.google-authenticator}/lib/security/pam_google_authenticator.so nullok no_increment_hotp # google_authenticator (order 12500)
          auth sufficient pam_permit.so

          session required pam_env.so conffile=/etc/pam/environment readenv=0 # env (order 10100)
          session required pam_unix.so # unix (order 10200)
          session required pam_loginuid.so # loginuid (order 10300)
          session optional ${pkgs.systemd}/lib/security/pam_systemd.so # systemd (order 12000)
        '';
    }; */
    services.openssh = {
      ports = [42069];
      enable = true;
      settings.PasswordAuthentication = false;
      settings.KbdInteractiveAuthentication = false;
      settings.PermitRootLogin = "no";
      settings.AllowGroups = [ "wheel" ];
      settings.AllowTcpForwarding = "no";
      settings.ClientAliveCountMax = 2;
      settings.MaxAuthTries = 3;
      settings.MaxSessions = 2;
      settings.TCPKeepAlive = "no";
      settings.AllowAgentForwarding = "no";
      settings.AuthenticationMethods = "publickey";
      #settings.AuthenticationMethods = "publickey,keyboard-interactive:pam";
    };

    networking.firewall.allowedTCPPorts = [42069];
  };
}
