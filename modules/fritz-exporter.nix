{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    fritz-exporter
  ];

  services.prometheus = {
    exporters = {
      fritz.settings = {
        devices = [
          {
            name = "Router";
            hostname = "fritz.box";
            username = "prometheus";
            password = "prometheus";
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
        enabledCollectors = [
          "fritz"   
        ];
        # You can pass extra options to the exporter using `extraFlags`, e.g.
        # to configure collectors or disable those enabled by default.
        # Enabling a collector is also possible using "--collector.[name]",
        # but is otherwise equivalent to using `enabledCollectors` above.
        #extraFlags = [ "--collector.ntp.protocol-version=4" "--no-collector.mdadm" ];
      };
    };
  };
}
