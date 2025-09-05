{ config, pkgs, lib, constants, ... }:

{
  services.harmonia.enable = true;
  services.harmonia.signKeyPaths = [ "/var/lib/secrets/harmonia.secret" ];
  services.harmonia.settings.tls_cert_path = "/etc/ssl/certs/kauderwels.ch_ssl_certificate_chain.cer";
  services.harmonia.settings.tls_key_path = "/etc/ssl/certs/_.kauderwels.ch_private_key.key";

  nix.settings.allowed-users = [ "harmonia" ];
  networking.firewall.interfaces."nebula.mesh".allowedTCPPorts = [ 443 80 5000];

  services.nebula.networks.mesh.firewall.inbound = lib.mkIf 
              (config.services.harmonia.enable && 
              config.services.nebula.networks.mesh.enable) 
      [
        {
          cidr = constants.nebula.cidr;
          port = 5000;
          proto = "tcp";
        }
        {
          cidr = constants.nebula.cidr;
          port = 443;
          proto = "tcp";
        }
        {
          cidr = constants.nebula.cidr;
          port = 80;
          proto = "tcp";
        }
      ];
  /* services.nginx = {
    enable = true;
    #forceSSL = true;
    recommendedTlsSettings = true;
    virtualHosts."cache.kauderwels.ch" = {
      sslCertificate = "/etc/ssl/certs/kauderwels.ch_ssl_certificate_chain.cer";
      sslCertificateKey = "/etc/ssl/certs/_.kauderwels.ch_private_key.key";
      locations."/".extraConfig = ''
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_redirect http:// https://;
        proxy_http_version 1.1;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
      '';
    };
  }; */
}