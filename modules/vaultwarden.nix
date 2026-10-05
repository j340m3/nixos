{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  domainName = "vaultwarden.kauderwels.ch";
in
{
  services.vaultwarden = {
    enable = true;
    config = {
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      DOMAIN = "https://${domainName}";
      # this is a password vault with a handful of family accounts, not a
      # public signup service. invitations stay open so an existing admin can
      # add someone by email; open registration would let anyone on the
      # internet create an account on it.
      DISABLE_USER_REGISTRATION = "true";
      INVITATIONS_ALLOWED = "true";
    };
    backupDir = "/var/backup/vaultwarden";
  };
  services.nginx = {
    enable = true;

    # Use recommended settings
    recommendedGzipSettings = true;

    virtualHosts."vaultwarden.kauderwels.ch" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}";
      };
    };
  };
  networking.firewall.allowedTCPPorts = [
    443
    80
  ];

  # fail2ban reads the journal, not a file: this host runs no rsyslog, so the
  # logpath this used to name (/var/log/syslog) never existed and the jail saw
  # no log lines at all. filter = "vaultwarden" resolves to the filter fail2ban
  # ships, which matches the current log format and also catches invalid admin
  # tokens and TOTP codes; the hand-written override it replaced matched an
  # older message this version no longer emits.
  services.fail2ban.jails."vaultwarden".settings = {
    enabled = true;
    filter = "vaultwarden";
    backend = "systemd";
    journalmatch = "_SYSTEMD_UNIT=vaultwarden.service";
    # 443 only: vaultwarden is behind nginx, and 8081 was never a port this
    # host listened on. deliberately not banaction_allports, which would ban
    # across every port including sshd: three wrong passwords here must not
    # lock anyone out of the only way into this machine.
    port = "443";
    # three misses inside four hours used to earn a four hour ban, which locks
    # out a family member who fumbles their password.
    maxretry = 5;
    bantime = 3600;
    findtime = 600;
  };
}
