{
  config,
  pkgs,
  lib,
  constants,
  ...
}:
{
  services.grafana = {
    enable = true;
    settings.server = {
      domain = "grafana.kauderwels.ch";
      http_port = 2342;
    };
    addr = "0.0.0.0";
    # FIXME
    settings.security.secret_key = "SW2YcwTIb9zpOOhoPsMm";
  };
  services.nginx.virtualHosts.${config.services.grafana.settings.server.domain} = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.grafana.settings.server.http_port}";
      proxyWebsockets = true;
    };
  };
  networking.firewall.interfaces."nebula.mesh".allowedTCPPorts = [
    config.services.grafana.settings.server.http_port
  ];
  services.nebula.networks.mesh.firewall.inbound =
    lib.mkIf (config.services.grafana.enable && config.services.nebula.networks.mesh.enable)
      [
        {
          cidr = constants.nebula.cidr;
          port = config.services.grafana.settings.server.http_port;
          proto = "any";
        }
      ];
}
