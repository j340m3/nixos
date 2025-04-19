{ self, config, lib, pkgs, ... }: {
  # Based on https://carjorvaz.com/posts/the-holy-grail-nextcloud-setup-made-easy-by-nixos/
  services = {
    nginx.virtualHosts = {
      "nextcloud.kauderwels.ch" = {
        forceSSL = true;
        sslCertificate = "/etc/ssl/certs/kauderwels.ch_ssl_certificate_chain.cer";
        sslCertificateKey = "/etc/ssl/certs/_.kauderwels.ch_private_key.key";
        listen = [
          {
            addr = "0.0.0.0";
            port = 443;
            ssl = true;
          }
        ];
      };
    };
    # 
    nextcloud = {
      enable = true;
      hostName = "nextcloud.kauderwels.ch";
      # Need to manually increment with every major upgrade.
      package = pkgs.nextcloud31;
      # Let NixOS install and configure the database automatically.
      database.createLocally = true;
      # Let NixOS install and configure Redis caching automatically.
      configureRedis = true;
      # Increase the maximum file upload size.
      maxUploadSize = "16G";
      https = true;
      autoUpdateApps.enable = true;
      extraAppsEnable = true;
      extraApps = with config.services.nextcloud.package.packages.apps; {
        # List of apps we want to install and are already packaged in
        # https://github.com/NixOS/nixpkgs/blob/master/pkgs/servers/nextcloud/packages/nextcloud-apps.json
        inherit calendar contacts notes onlyoffice tasks cookbook qownnotesapi;
        # Custom app example.
        /* socialsharing_telegram = pkgs.fetchNextcloudApp rec {
          url =
            "https://github.com/nextcloud-releases/socialsharing/releases/download/v3.0.1/socialsharing_telegram-v3.0.1.tar.gz";
          license = "agpl3";
          sha256 = "sha256-8XyOslMmzxmX2QsVzYzIJKNw6rVWJ7uDhU1jaKJ0Q8k=";
        }; */
      };
      settings = {
        overwriteProtocol = "https";
        default_phone_region = "DE";
      };
      config = {
        dbtype = "pgsql";
        adminuser = "admin";
        adminpassFile = "/etc/nextcloud-admin-pass";
      };
      # Suggested by Nextcloud's health check.
      phpOptions."opcache.interned_strings_buffer" = "16";
    };
    # Nightly database backups.
    postgresqlBackup = {
      enable = true;
      startAt = "*-*-* 01:15:00";
    };
  };
  services.fail2ban.jails."nextcloud".settings = {
    enabled = true;
    filter = "nextcloud";
    logpath = "/var/log/syslog";
    port = [ 80 443 ];
    banaction = "%(banaction_allports)s"; 
    maxretry = 3;
    backend = "auto";
    protocol = "tcp";
    filter = "nextcloud";
    bantime = 86400;
    findtime = 43200;
  };

  environment.etc."fail2ban/filter.d/nextcloud.local".text = ''
    [Definition]
    _groupsre = (?:(?:,?\s*"\w+":(?:"[^"]+"|\w+))*)
    failregex = ^\{%(_groupsre)s,?\s*"remoteAddr":"<HOST>"%(_groupsre)s,?\s*"message":"Login failed:
                ^\{%(_groupsre)s,?\s*"remoteAddr":"<HOST>"%(_groupsre)s,?\s*"message":"Trusted domain error.
    datepattern = ,?\s*"time"\s*:\s*"%%Y-%%m-%%d[T ]%%H:%%M:%%S(%%z)?"
    '';
}