{ self, config, lib, pkgs, ... }: {
  services = {
    nginx.virtualHosts = {
      "immich.kauderwels.ch" = {
        forceSSL = true;
        sslCertificate = "/etc/ssl/certs/kauderwels.ch_ssl_certificate_chain.cer";
        sslCertificateKey = "/etc/ssl/certs/_.kauderwels.ch_private_key.key";
        # listen = [
        #   {
        #     addr = "10.0.0.3";
        #     port = 443;
        #     ssl = true;
        #   }
        # ];
        locations."/" = {
            proxyPass = "http://10.0.0.3:2283";
            proxyWebsockets = false;
            extraConfig =
                "proxy_ssl_server_name on;" +
                "proxy_pass_header Authorization;";
        };
      };
    };
  };
}