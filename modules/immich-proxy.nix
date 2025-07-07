{ self, config, lib, pkgs, ... }: {
  services.immich-public-proxy = {
      enable = true;
      immichUrl = "http://10.0.0.3:2283";
      port = 3001;
    };
    
  services.nginx.virtualHosts = {
      "immich.kauderwels.ch" = {
        forceSSL = true;
        sslCertificate = "/etc/ssl/certs/kauderwels.ch_ssl_certificate_chain.cer";
        sslCertificateKey = "/etc/ssl/certs/_.kauderwels.ch_private_key.key";
        listen = [
          {
            addr = "0.0.0.0";
            port = 3001;
            ssl = true;
          }
        ];
      };
}