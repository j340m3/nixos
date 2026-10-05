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
        # vaultwarden takes the client address from X-Real-IP, and this vhost set
        # no proxy headers at all, so every request was logged as coming from
        # nginx's own 127.0.0.1. that made the fail2ban jail useless: the filter
        # matched, but the address was always localhost, which fail2ban ignores,
        # so nothing could ever be banned. overwritten unconditionally, so a
        # client cannot spoof its address by sending the header itself.
        extraConfig = ''
          proxy_set_header X-Real-IP $remote_addr;
        '';
      };
    };
  };
  networking.firewall.allowedTCPPorts = [
    443
    80
  ];

  # fail2ban reads the journal, not a file: this host runs no rsyslog, so the
  # logpath this used to name (/var/log/syslog) never existed and the jail saw
  # no log lines at all.
  #
  # the filter fail2ban ships cannot work here either. its regex is anchored at
  # the start of the line and expects [vaultwarden::api::...] there, with no
  # %(__prefix_line)s in front of it, but a journal line begins with the host
  # name and timestamp:
  #
  #   pricklepants vaultwarden[159140]: [2026-10-05 12:31:26.841][vaultwarden::...
  #
  # so it can never match, on either -o short or -o cat. checked on this host:
  # fail2ban-regex returned 0 hits for the shipped filter against its own log,
  # and 4 for the pattern below. that is why the override exists, and why
  # deleting it in 7777ee9 left the jail silently counting nothing.
  # filter = "vaultwarden" so fail2ban reads filter.d/vaultwarden.conf and then
  # filter.d/vaultwarden.local, and the .local overrides the shipped failregex.
  # the override must keep the same name as the filter it shadows: naming it
  # something else, or pointing filter at a dash name while the file is
  # vaultwarden.local, leaves fail2ban looking for a file that does not exist and
  # it skips the jail with "Found no accessible config files".
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

  # %(__prefix_line)s would normally absorb the host name and timestamp, but the
  # shipped filter uses a bare ^ instead and so never fires here. matching from
  # ^.* keeps the same intent. anchored on "IP: <HOST>." rather than <HOST>
  # alone: \S+ would otherwise swallow the trailing period and fail2ban would
  # ban "92.208.27.155." instead of the address.
  environment.etc."fail2ban/filter.d/vaultwarden.local".text = ''
    [INCLUDES]
    before = common.conf

    [Definition]
    failregex = ^.*Username or password is incorrect\. Try again\. IP: <HOST>\. Username:.*$
    ignoreregex =
  '';
}
