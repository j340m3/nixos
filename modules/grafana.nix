{ config, pkgs, ... }:
{
  services.grafana = {
    enable = true;
    domain = "grafana.kauderwels.ch";
    port = 2342;
    addr = "127.0.0.1";
  };
  services.nginx.virtualHosts.${config.services.grafana.domain} = {
    locations."/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.grafana.port}";
        proxyWebsockets = true;
    };
  };
  networking.firewall.interfaces."nebula.mesh".allowedTCPPorts = [ config.services.grafana.port];
  services.nebula.networks.mesh.firewall.inbound = lib.mkIf 
              (config.services.grafana.enable && 
              config.services.nebula.networks.mesh.enable) 
      [
        {
          cidr = constants.nebula.cidr;
          port = config.services.grafana.port;
          proto = "any";
        }
      ];
}
