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

}
