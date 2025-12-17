{ config, pkgs, ... }:
{
  services.prometheus = {
    enable = true;
    port = 9001;
    scrapeConfigs = [
      {
        job_name = "woody";
        static_configs = [{
          targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
        }];
      }
      {
        job_name = "fritz";
        scrape_timeout = "120s"; # 2* 30s since i have 2 hosts that need 30s according to the documentation
        scrape_interval = "120s";
        static_configs = [{
          targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.fritz.port}" ];
        }];
      }
    ];

  };

}
