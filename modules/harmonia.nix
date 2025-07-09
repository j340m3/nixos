{ config, pkgs, lib, ... }:

{
  services.harmonia.enable = true;
  services.harmonia.signKeyPaths = [ "/var/lib/secrets/harmonia.secret" ];

  nix.settings.allowed-users = [ "harmonia" ];
  networking.firewall.interfaces."nebula.mesh".allowedTCPPorts = [ 443 80 ];

  services.nginx = {
    enable = true;
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
  };
}