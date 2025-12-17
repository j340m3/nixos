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
        scrape_timeout = "60s";
        scrape_interval = "60s";
        static_configs = [{
          targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.fritz.port}" ];
        }];
      }
    ];

  };

}
