{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

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
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}";
      };
      # sslCertificate = "/etc/ssl/certs/kauderwels.ch_ssl_certificate.cer";
      sslCertificate = "/etc/ssl/certs/kauderwels.ch_ssl_certificate_chain.cer";
      sslCertificateKey = "/etc/ssl/certs/_.kauderwels.ch_private_key.key";
    };
  };
  networking.firewall.allowedTCPPorts = [ 443 ];

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
