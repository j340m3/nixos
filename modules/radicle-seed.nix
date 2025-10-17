{config, constants, lib, ...}:{
  services.radicle = {
    enable = true;
    privateKeyFile = config.sops.secrets."radicle/private".path;
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINQqjSkV3STF+guLHa3kKZnkj3VHI8kk1Ppzo42s2ArO jerome@kauderwels.ch";
    #node.openFirewall = true;
    node.listenAddress = "[::0]";
    settings = {
        "web" = {
          "pinned" = {
            "repositories" = [
              # "rad:z2eeB9LF8fDNJQaEcvAWxQmU7h2PG" # fedimint
              # "rad:zPs9xPpx5ehT56shVzQ4BUnov9uE"  # fedimint-infra
              # "rad:z3j99jVF5NuLGuMj7LX9WZ8WvNaLo" # fedimint-ui
            ];
          };
        };
    };
    httpd.enable = true;
    httpd.nginx.serverName = "radicle.kauderwels.ch";
    #httpd.nginx.enableACME = true;
    #httpd.nginx.forceSSL = true;
  };

  sops.secrets."radicle/private" = {
    sopsFile = ../secrets/${config.networking.hostName}/secrets.yaml;
  };

  networking.firewall.interfaces."nebula.mesh".allowedTCPPorts = [ config.services.radicle.port ];
  networking.firewall.allowedTCPPorts = [ config.services.radicle.port ];
  services.nebula.networks.mesh.firewall.inbound = lib.mkIf 
              (config.services.radicle.enable && 
              config.services.nebula.networks.mesh.enable) 
      [
        {
          cidr = constants.nebula.cidr;
          port = config.services.radicle.port;
          proto = "any";
        }
      ];
}
