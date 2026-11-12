# dendritic: aspect with absorbed body (was modules/_common/ssh.nix).
{ inputs, ... }:
let
  constants = import ../global/_constants.nix;
in
{
  flake.modules.nixos.ssh =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      options = { };
      config = {
        programs.ssh.extraConfig = ''
          Host *
            ConnectTimeout 5
        '';

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
          ignoreIP = [ "10.0.0.0/8" ];
        };
        # fail2ban can silently stall (pricklepants 2026-11-07..12: daemon alive but
        # processed zero journal entries for 5 days while a sshd flood ran; restart
        # fixed it instantly). It never exits when stalled, so Restart=always alone
        # cannot help - RuntimeMaxSec forces a periodic replacement. Bans survive
        # restarts via the sqlite db.
        systemd.services.fail2ban = {
          serviceConfig = {
            Restart = lib.mkDefault "always";
            RestartSec = lib.mkDefault "10s";
          };
          unitConfig.RuntimeMaxSec = lib.mkDefault "12h";
        };
        /*
          security.pam.services = {
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
          };
        */
        services.openssh = {
          ports = [ constants.sshPort ];
          enable = true;
          settings.PasswordAuthentication = false;
          settings.KbdInteractiveAuthentication = false;
          settings.PermitRootLogin = "no";
          settings.AllowGroups = [
            "wheel"
            "remotebuild"
            "borg"
          ];
          settings.AllowTcpForwarding = "no";
          settings.ClientAliveCountMax = 2;
          settings.MaxAuthTries = 3;
          settings.MaxSessions = 2;
          settings.TCPKeepAlive = "no";
          settings.AllowAgentForwarding = "no";
          settings.AuthenticationMethods = "publickey";
          #settings.AuthenticationMethods = "publickey,keyboard-interactive:pam";
        };

        services.endlessh = {
          enable = true;
          port = 22;
          openFirewall = true;
        };

        # Brute-force floods on public VPS hosts must not drown the journal
        # and the loghost pipeline (pricklepants 2026-11-12: days of
        # rsyslogd at ~46% CPU). Journald per-unit cap for sshd only; the
        # flood volume itself is cut host-side with firewall extraCommands
        # (see pricklepants configuration.nix). systemd defaults are 10000
        # msgs / 30s, far too generous for an attack firehose.
        systemd.services.sshd.unitConfig = {
          LogRateLimitIntervalSec = lib.mkDefault "10s";
          LogRateLimitBurst = lib.mkDefault 100;
        };

        networking.firewall.allowedTCPPorts = [ constants.sshPort ];
        # openssh.enable is always true in this module, so no gate is needed;
        # the nebula aspect renders this as an inbound mesh rule.
        mesh.openInbound = [
          {
            port = constants.sshPort;
            proto = "any";
          }
        ];
      };
    };
}
