{
  flake.modules.nixos.prometheus =
    { config, ... }:
    let
      constants = import ../global/_constants.nix;
      # Real hosts exposing node_exporter (modules/services/node-exporter.nix).
      # sid (WSL) and the throwaway bootstrap hosts never import the aspect and
      # are deliberately absent here too, so a missing target is a real alarm.
      nodeHosts = [
        "buzz"
        "jessie"
        "lenny"
        "mrpotatohead"
        "pricklepants"
        "rex"
        "slinky"
        "woody"
        "zurg"
      ];
      nodePort = config.services.prometheus.exporters.node.port;
    in
    {
      services.prometheus = {
        enable = true;
        port = 9001;
        scrapeConfigs = [
          {
            # The mesh is the transport (the exporter is firewalled to the mesh
            # CIDR on every host); the instance label is the roster name, not
            # the address, so dashboards and alerts survive address changes.
            job_name = "node";
            static_configs = map (host: {
              targets = [ "${constants.host.${host}.ip}:${toString nodePort}" ];
              labels.instance = host;
            }) nodeHosts;
          }
          {
            job_name = "fritz";
            scrape_timeout = "120s"; # 2* 30s since i have 2 hosts that need 30s according to the documentation
            scrape_interval = "120s";
            static_configs = [
              {
                targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.fritz.port}" ];
              }
            ];
          }
        ];

      };

    };
}
