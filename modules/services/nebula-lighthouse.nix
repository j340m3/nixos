{
  flake.modules.nixos.nebula-lighthouse =
    { config, ... }:
    {
      services.nebula.networks.mesh = {
        enable = true;
        isLighthouse = true;
        isRelay = true;
        cert = config.sops.secrets."nebula/self_crt".path; # "/run/secrets/nebula/self.crt";
        key = config.sops.secrets."nebula/self_key".path; # "/run/secrets/nebula/self.key";
        ca = config.sops.secrets."nebula/ca_crt".path;
        # cert = "/etc/nebula/pricklepants.crt"; # The name of this lighthouse is beacon.
        # key = "/etc/nebula/pricklepants.key";
        # ca = "/etc/nebula/ca.crt";
        staticHostMap = {
          "10.0.0.5" = [
            "[2a01:239:27f:fd00::1]:4242"
            "194.164.54.40:4242"
          ];
        };
        settings = {
          lighthouse = {
            serve_dns = true;
            dns = {
              host = "0.0.0.0";
              port = 53;
            };
          };
          static_map = {
            network = "ip";
          };
          cipher = "aes";
          punchy = {
            punch = true;
            reload = true;
          };
        };
        firewall.outbound = [
          {
            cidr = config.systemConstants.nebula.cidr;
            port = "any";
            proto = "any";
          }
        ];
        firewall.inbound = [
          {
            cidr = config.systemConstants.nebula.cidr;
            port = "42069";
            proto = "tcp";
          }
          {
            cidr = config.systemConstants.nebula.cidr;
            port = "any";
            proto = "icmp";
          }
          {
            cidr = config.systemConstants.nebula.cidr;
            port = "53";
            proto = "udp";
          }
          {
            cidr = config.systemConstants.nebula.cidr;
            port = "10050";
            proto = "any";
          }
        ];
      };

      sops.secrets."nebula/ca_crt" = {
        restartUnits = [ "nebula@mesh.service" ];
        owner = "nebula-mesh";
        group = "nebula-mesh";
        path = "/nix/persist/etc/nebula/ca.crt";
      };
      sops.secrets."nebula/self_crt" = {
        sopsFile = ../../../secrets/hosts/${config.networking.hostName}/secrets.yaml;
        restartUnits = [ "nebula@mesh.service" ];
        owner = "nebula-mesh";
        group = "nebula-mesh";
        path = "/nix/persist/etc/nebula/self.crt";
      };
      sops.secrets."nebula/self_key" = {
        sopsFile = ../../../secrets/hosts/${config.networking.hostName}/secrets.yaml;
        restartUnits = [ "nebula@mesh.service" ];
        owner = "nebula-mesh";
        group = "nebula-mesh";
        path = "/nix/persist/etc/nebula/self.key";
      };
    };
}
