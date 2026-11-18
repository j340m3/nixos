{
  flake.modules.nixos.fritz-exporter =
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
                }
              ];
            };
          };
        };
      };

      sops.secrets."prometheus/fritz/router" = {
        sopsFile = ../../secrets/hosts/${config.networking.hostName}/secrets.yaml;
        restartUnits = [ "prometheus-fritz-exporter.service" ];
        owner = "fritz-exporter";
        group = "fritz-exporter";
      };

      sops.secrets."prometheus/fritz/fritz-rep1" = {
        sopsFile = ../../secrets/hosts/${config.networking.hostName}/secrets.yaml;
        restartUnits = [ "prometheus-fritz-exporter.service" ];
        owner = "fritz-exporter";
        group = "fritz-exporter";
      };
    };
}
