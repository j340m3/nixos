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
    };
    backupDir = "/var/backup/vaultwarden";
  }; 
  services.nginx = {
    enable = true;
    
    # Use recommended settings
    recommendedGzipSettings = true;

    virtualHosts."vaultwarden.kauderwels.ch" = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}";
      };
      # sslCertificate = "/etc/ssl/certs/kauderwels.ch_ssl_certificate.cer";
      #sslCertificate = "/etc/ssl/certs/kauderwels.ch_ssl_certificate_chain.cer";
      #sslCertificateKey = "/etc/ssl/certs/_.kauderwels.ch_private_key.key";
    };
  };
  networking.firewall.allowedTCPPorts = [ 443 80 ];
  
  security.acme = {
      acceptTerms = true;
      defaults = {
        email = "jerome.bergmann@posteo.de";
        webroot = "/var/lib/acme/acme-challenge/";
        #dnsProvider = "cloudflare";
        # location of your CLOUDFLARE_DNS_API_TOKEN=[value]
        # https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html#EnvironmentFile=
        #environmentFile = "/REPLACE/WITH/YOUR/PATH";
      };
      certs.${domainName}.group = config.services.nginx.group;
    };

  # for acme plain http challenge
  # networking.firewall.allowedTCPPorts = [ 80 ];

  # webserver for http challenge
  services.nginx = {
    enable = true;
    virtualHosts.${domainName} = {
      forceSSL = true;
      useACMEHost = domainName;
      locations."/.well-known/".root = "/var/lib/acme/acme-challenge/";
    };
  };

  services.fail2ban.jails."vaultwarden".settings = {
    enabled = true;
    filter = "vaultwarden";
    logpath = "/var/log/syslog";
    port = "80,443,8081";
    banaction = "%(banaction_allports)s"; 
    maxretry = 3;
    bantime = 14400;
    findtime = 14400;
  };

  environment.etc."fail2ban/filter.d/vaultwarden.local".text = ''
    [INCLUDES]
    before = common.conf

    [Definition]
    failregex = ^.*?Username or password is incorrect\. Try again\. IP: <ADDR>\. Username:.*$
    ignoreregex =
    '';
}
