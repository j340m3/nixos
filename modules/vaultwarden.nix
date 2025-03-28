{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  services.vaultwarden.enable = true;

  services.nginx = {
    enable = true;
    
    # Use recommended settings
    recommendedGzipSettings = true;

    virtualHosts."vaultwarden.kauderwels.ch" = {
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}";
      };
      sslCertificate = "/etc/ssl/certs/kauderwels.ch_ssl_certificate.cer";
      sslCertificateKey = "/etc/ssl/certs/_.kauderwels.ch_private_key.key";
    };
  };
  networking.firewall.allowedTCPPorts = [ 443 ];
}
