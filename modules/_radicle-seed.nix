{
  config,
  constants,
  lib,
  ...
}:
{
  services.radicle = {
    enable = true;
    privateKey = config.sops.secrets."radicle/private".path;
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINQqjSkV3STF+guLHa3kKZnkj3VHI8kk1Ppzo42s2ArO jerome@kauderwels.ch";
    node = {
      openFirewall = true;
      listenAddress = "[::0]";
    };
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
    httpd.nginx.enableACME = true;
    httpd.nginx.forceSSL = true;
  };

  # enableACME needs a real nginx; without this the httpd vhost is phantom
  # (jessie had no nginx in its closure at all)
  services.nginx.enable = true;

  # web UI cert: enableACME generates the entry incl. nginx reload on renewal;
  # explicit group mirrors modules/_pihole.nix (key readable by the proxy group)
  security.acme.certs."radicle.kauderwels.ch" = {
    group = config.services.nginx.group;
  };

  sops.secrets."radicle/private" = {
    sopsFile = ../secrets/hosts/${config.networking.hostName}/secrets.yaml;
  };

  networking.firewall.interfaces."nebula.mesh".allowedTCPPorts = [
    config.services.radicle.node.listenPort
    80
    443
  ];
  networking.firewall.allowedTCPPorts = [
    config.services.radicle.node.listenPort
    80
    443
  ];
  services.nebula.networks.mesh.firewall.inbound =
    lib.mkIf (config.services.radicle.enable && config.services.nebula.networks.mesh.enable)
      [
        {
          cidr = constants.nebula.cidr;
          port = config.services.radicle.node.listenPort;
          proto = "any";
        }
        {
          cidr = constants.nebula.cidr;
          port = 80;
          proto = "any";
        }
        {
          cidr = constants.nebula.cidr;
          port = 443;
          proto = "any";
        }
      ];
}
