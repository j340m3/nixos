{
  config,
  lib,
  pkgs,
  ...
}:
# Adapted from:
# https://gitlab.com/famedly/conduit/-/blob/3bfdae795d4d9ec9aeaac7465e7535ac88e47756/nix/README.md
let
  server_name = "kauderwels.ch";
  matrix_hostname = "matrix.${server_name}";
in {
  services.matrix-conduit = {
    enable = true;
    #package = pkgs.conduwuit_git;
    settings.global = {
      allow_registration = true;
      allow_federation = true;
      database_backend = "rocksdb";
      inherit server_name;
      new_user_displayname_suffix = "";
    };
    settings.tls = {
      certs = "/etc/ssl/certs/kauderwels.ch_ssl_certificate.cer";
      key = "/etc/ssl/certs/_.kauderwels.ch_private_key.key";
    };
  };

  # Fix for new binary name in 0.5.0
  #systemd.services.conduit.serviceConfig.ExecStart = lib.mkForce "${pkgs.conduwuit_git}/bin/conduwuit";

  services.nginx = {
    virtualHosts = {
      "${matrix_hostname}" = {
        sslCertificate = "/etc/ssl/certs/kauderwels.ch_ssl_certificate.cer";
        sslCertificateKey = "/etc/ssl/certs/_.kauderwels.ch_private_key.key";
        extraConfig = ''
          merge_slashes off;
        '';
        forceSSL = true;
        http3 = true;
        http3_hq = true;
        kTLS = true;
        listen = [
          {
            addr = "0.0.0.0";
            port = 443;
            ssl = true;
          }
          {
            addr = "[::]";
            port = 443;
            ssl = true;
          }
          {
            addr = "0.0.0.0";
            port = 8448;
            ssl = true;
          }
          {
            addr = "[::]";
            port = 8448;
            ssl = true;
          }
        ];
        locations."/_matrix/" = {
          proxyPass = "http://backend_conduit$request_uri";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_buffering off;
          '';
        };
        locations."/" = {
          return = "200 '<html><head><style>p.penis {font-size: 100px;}</style></head><body><p class=\"penis\">PENIS</p></body></html>'";
          extraConfig = ''
            default_type text/html;
          '';
        };
        quic = true;
        #useACMEHost = "kauderwels.ch";
      };
    };

    upstreams = {
      "backend_conduit" = {
        servers = {
          "[::1]:${toString config.services.matrix-conduit.settings.global.port}" = {};
        };
      };
    };
    package = pkgs.nginxQuic;
  };

  networking.firewall = {
    allowedTCPPorts = [80 443 8448];
    allowedUDPPorts = [80 443 8448];
  };
}
ervices.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.mate.enable = true;