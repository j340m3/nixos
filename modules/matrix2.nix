{ self, inputs, config, lib, pkgs,
  host, repo, user, network, machine,
  ...
}:
let
  # The hostname that will appear in your user and room IDs
  server_name = "kauderwels.ch";

  # The hostname that Conduit actually runs on
  # This can be the same as `server_name` if you want. This is only necessary
  # when Conduit is running on a different machine than the one hosting your
  # root domain. This configuration also assumes this is all running on a single
  # machine, some tweaks will need to be made if this is not the case.
  matrix_hostname = "matrix.${server_name}";

  # An admin email for TLS certificate notifications
  admin_email = "admin@${server_name}";

  # Build a dervation that stores the content of `${server_name}/.well-known/matrix/server`
  well_known_server = pkgs.writeText "well-known-matrix-server" ''
    {
      "m.server": "${matrix_hostname}"
    }
  '';

  # Build a dervation that stores the content of `${server_name}/.well-known/matrix/client`
  well_known_client = pkgs.writeText "well-known-matrix-client" ''
    {
      "m.homeserver": {
        "base_url": "https://${matrix_hostname}"
      }
    }
  '';
in

{
  # Configure Conduit itself
  services.matrix-conduit = {
    enable = true;

    # This causes NixOS to use the flake defined in this repository instead of
    # the build of Conduit built into nixpkgs.
    # package = inputs.conduit.packages.${pkgs.system}.default;

    settings.global = {
      inherit server_name;
      allow_encryption = true;
      allow_federation = true;
      allow_registration = true;
      database_backend = "rocksdb";
      #package = inputs.conduwuit;
      package = pkgs.matrix-conduit;
      well_known = {
          client = "https://${matrix_hostname}";
          server = "${matrix_hostname}:443";
        };
    };
    settings.tls = {
      certs = "/etc/ssl/certs/kauderwels.ch_ssl_certificate_chain.cer";
      key = "/etc/ssl/certs/_.kauderwels.ch_private_key.key";
    };
  };

  # Configure automated TLS acquisition/renewal
  #security.acme = {
  #  acceptTerms = true;
  #  defaults = {
  #    email = admin_email;
  #  };
  #};

  # ACME data must be readable by the NGINX user
  #users.users.nginx.extraGroups = [
  #  "acme"
  #];

  # Configure NGINX as a reverse proxy
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;

    virtualHosts = {
      "${matrix_hostname}" = {
        forceSSL = true;
        sslCertificate = "/etc/ssl/certs/kauderwels.ch_ssl_certificate_chain.cer";
        sslCertificateKey = "/etc/ssl/certs/_.kauderwels.ch_private_key.key";
        #enableACME = true;

        listen = [
          {
            addr = "0.0.0.0";
            port = 443;
            ssl = true;
          }
          {
            addr = "0.0.0.0";
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
        locations."=/.well-known/matrix/server" = {
          # Use the contents of the derivation built previously
          alias = "${well_known_server}";

          extraConfig = ''
            # Set the header since by default NGINX thinks it's just bytes
            default_type application/json;
          '';
        };

        locations."=/.well-known/matrix/client" = {
          # Use the contents of the derivation built previously
          alias = "${well_known_client}";

          extraConfig = ''
            # Set the header since by default NGINX thinks it's just bytes
            default_type application/json;

            # https://matrix.org/docs/spec/client_server/r0.4.0#web-browser-clients
            add_header Access-Control-Allow-Origin "*";
          '';
        };

        extraConfig = ''
          merge_slashes off;
        '';
        root = pkgs.element-web.override {
          conf = {
            default_server_config."m.homeserver" = {
              "base_url" = "https://${matrix_hostname}";
              "server_name" = "kauderwels.ch";
            };
          };
        };
      };

     /*  "${server_name}" = {
        forceSSL = true;
        sslCertificate = "/etc/ssl/certs/kauderwels.ch_ssl_certificate.cer";
        sslCertificateKey = "/etc/ssl/certs/_.kauderwels.ch_private_key.key";
        #enableACME = true;

        locations."=/.well-known/matrix/server" = {
          # Use the contents of the derivation built previously
          alias = "${well_known_server}";

          extraConfig = ''
            # Set the header since by default NGINX thinks it's just bytes
            default_type application/json;
          '';
        };

        locations."=/.well-known/matrix/client" = {
          # Use the contents of the derivation built previously
          alias = "${well_known_client}";

          extraConfig = ''
            # Set the header since by default NGINX thinks it's just bytes
            default_type application/json;

            # https://matrix.org/docs/spec/client_server/r0.4.0#web-browser-clients
            add_header Access-Control-Allow-Origin "*";
          '';
        };
      }; */
    };
    
    upstreams = {
      "backend_conduit" = {
        servers."localhost:${toString config.services.matrix-conduit.settings.global.port}" = { };
      };
    };
  };

  # Open firewall ports for HTTP, HTTPS, and Matrix federation
  networking.firewall.allowedTCPPorts = [ 80 443 8448 ];
  networking.firewall.allowedUDPPorts = [ 80 443 8448 ];
  

  services.fail2ban.jails."matrix".settings = {
    enabled = true;
    filter = "matrix";
    logpath = "/var/log/syslog";
    maxretry = 5;
  };

  environment.etc."fail2ban/filter.d/matrix.local".text = ''
    # matrix-synapse configuration file
    #
    [Init]
    maxlines = 3
    [Definition]
    # Option:  failregex
    # Notes.:  regex to match the password failures messages in the logfile. The
    #          host must be matched by a group named "host". The tag "<HOST>" can
    #          be used for standard IP/hostname matching and is only an alias for
    #          (?:::f{4,6}:)?(?P<host>\S+)
    # Values:  TEXT
    #
    failregex = .*::ffff:<HOST> - 8448 - Received request: POST.*\n.*Got login request.*\n.*Attempted to login as.*
                .*::ffff:<HOST> - 8448 - Received request: POST.*\n.*Got login request.*\n.*Failed password login.*
    # Option:  ignoreregex
    # Notes.:  regex to ignore. If this regex matches, the line is ignored.
    # Values:  TEXT
    #
    ignoreregex =
    '';

    sops.secrets."borg/matrix" = {
      sopsFile = ../secrets/${config.networking.hostName}/secrets.yaml;
    };

    services.borgbackup.jobs.matrix = {
    paths = "${config.services.matrix-conduit.settings.global.database_path}";
    encryption.mode = "none";
    environment.BORG_RSH = "ssh -i ${config.sops.secrets."borg/matrix".path}";
    repo = "borg@10.0.0.3:.";
    compression = "auto,lzma";
    startAt = "daily";
    preHook = "systemctl stop conduit";
    postHook = "systemctl start conduit";
  };

  # Send an email whenever auto upgrade fails
    systemd.services."borgbackup-job-matrix".onFailure =
      lib.mkIf config.systemd.services."notify-telegram@".enable
      [ "notify-telegram@%i.service" ];
}
