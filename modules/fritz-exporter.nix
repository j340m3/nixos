{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    fritz-exporter
  ];

  services.prometheus = {
    exporters = {
      fritz = {
        enable = true;
        settings = {
          devices = [
            {
              name = "Router";
              hostname = "fritz.box";
              username = "prometheus";
              password_file = config.sops.secrets."prometheus/fritz/router".path;
              host_info = true;
            }
            {
              name = "Repeater 1";
              hostname = "fritz-rep1.fritz.box";
              username = "prometheus";
              password_file = config.sops.secrets."prometheus/fritz/fritz-rep1".path;
              host_info = true;
            }
          ];
        };
      };
      
      node = {
        enable = true;
        port = 9000;
        # For the list of available collectors, run, depending on your install:
        # - Flake-based: nix run nixpkgs#prometheus-node-exporter -- --help
        # - Classic: nix-shell -p prometheus-node-exporter --run "node_exporter --help"
        # enabledCollectors = [
        #   "fritz"   
        # ];
        # You can pass extra options to the exporter using `extraFlags`, e.g.
        # to configure collectors or disable those enabled by default.
        # Enabling a collector is also possible using "--collector.[name]",
        # but is otherwise equivalent to using `enabledCollectors` above.
        #extraFlags = [ "--collector.ntp.protocol-version=4" "--no-collector.mdadm" ];
      };
    };
  };

  sops.secrets."prometheus/fritz/router" = {
    sopsFile = ../secrets/${config.networking.hostName}/secrets.yaml;
    restartUnits = ["prometheus-fritz-exporter.service"];
    owner = "fritz-exporter";
    group = "fritz-exporter";
  };

  sops.secrets."prometheus/fritz/fritz-rep1" = {
    sopsFile = ../secrets/${config.networking.hostName}/secrets.yaml;
    restartUnits = ["prometheus-fritz-exporter.service"];
    owner = "fritz-exporter";
    group = "fritz-exporter";
  };
}
