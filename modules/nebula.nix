{
  config,
  pkgs,
  lib,
  constants,
  ...
}:
{
  # Mesh member => remote-build accept side (every mesh host builds for the
  # fleet). The two lighthouses (pricklepants, buzz) define nebula inline in
  # their host files, so they import ../../modules/remote-builder.nix there.
  imports = [ ./remote-builder.nix ./yggdrasil.nix ];

  environment.systemPackages = with pkgs; [
    nebula
  ];

  services.nebula.networks.mesh = {
    listen.host = "[::]";
    enable = true;
    isLighthouse = false;
    # roster in global/constants.nix: names -> mesh ip + public endpoints
    lighthouses = map (h: constants.host.${h}.ip) constants.lighthouses;
    relays = map (h: constants.host.${h}.ip) constants.lighthouses;
    settings = {
      cipher = "aes";
      static_map = {
        network = "ip";
      };
      punchy = {
        punch = true;
        respond = true;
      };
      dns = {
        host = constants.host.${constants.nebula.dns}.ip;
        port = 53;
      };
    };
    cert = config.sops.secrets."nebula/self_crt".path; # "/run/secrets/nebula/self.crt";
    key = config.sops.secrets."nebula/self_key".path; # "/run/secrets/nebula/self.key";
    ca = config.sops.secrets."nebula/ca_crt".path; # "/run/secrets/nebula/ca.crt";
    staticHostMap = constants.nebula.staticMap config.networking.hostName;
    firewall.outbound = [
      {
        cidr = constants.nebula.cidr;
        port = "any";
        proto = "any";
      }
    ];

    firewall.inbound = [
      {
        cidr = constants.nebula.cidr;
        proto = "icmp";
        port = "any";
      }
      /*
        {
          cidr = constants.nebula.cidr;
          port = "any";
          proto = "any";
        }
      */
    ];
    /*
      {
        cidr = constants.nebula.cidr;
        port = "any";
        proto = "any";
      }]
      ++ lib.optional (config.useComin) ({
        cidr = constants.nebula.cidr;
        port = "4242";
        proto = "any";
      });
    */

  };
  sops.secrets."nebula/ca_crt" = {
    restartUnits = [ "nebula@mesh.service" ];
    owner = "nebula-mesh";
    group = "nebula-mesh";
    path = "/etc/nebula/ca.crt";
  };
  sops.secrets."nebula/self_crt" = {
    sopsFile = ../secrets/hosts/${config.networking.hostName}/secrets.yaml;
    restartUnits = [ "nebula@mesh.service" ];
    owner = "nebula-mesh";
    group = "nebula-mesh";
    path = "/etc/nebula/self.crt";
  };
  sops.secrets."nebula/self_key" = {
    sopsFile = ../secrets/hosts/${config.networking.hostName}/secrets.yaml;
    restartUnits = [ "nebula@mesh.service" ];
    owner = "nebula-mesh";
    group = "nebula-mesh";
    path = "/etc/nebula/self.key";
  };
}
