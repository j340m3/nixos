# Node exporter (improvement session 2026-11-12): the metric surface every
# real host exposes to woody's prometheus (modules/services/prometheus.nix).
# Imported per host rather than folded into a shared aspect: the throwaway
# bootstrap hosts and sid (WSL) must not appear in the fleet dashboards, and
# they import neither system-default nor nebula.
{
  flake.modules.nixos.node-exporter =
    { config, ... }:
    {
      services.prometheus.exporters.node = {
        enable = true;
        # 9100 is the exporter default and the fleet convention; the scrape job
        # in modules/services/prometheus.nix reads this same option. Bind
        # anywhere but let the two mesh gates decide reachability — binding the
        # nebula address would race the interface coming up.
        listenAddress = "0.0.0.0";
        openFirewall = false;
        # For the list of available collectors, run, depending on your install:
        # - Flake-based: nix run nixpkgs#prometheus-node-exporter -- --help
        # - Classic: nix-shell -p prometheus-node-exporter --run "node_exporter --help"
        # You can pass extra options to the exporter using `extraFlags`, e.g.
        # to configure collectors or disable those enabled by default.
        # Enabling a collector is also possible using "--collector.[name]",
        # but is otherwise equivalent to using `enabledCollectors` above.
        #extraFlags = [ "--collector.ntp.protocol-version=4" "--no-collector.mdadm" ];
      };

      # Both gatekeeping layers, same pattern as grafana/radicle-seed: nebula's
      # own network firewall (mesh cidr) and the host firewall on the mesh
      # device. Nothing outside the mesh CIDR can reach the exporter.
      networking.firewall.interfaces."nebula.mesh".allowedTCPPorts = [
        config.services.prometheus.exporters.node.port
      ];
      mesh.openInbound = [
        {
          port = config.services.prometheus.exporters.node.port;
          proto = "tcp";
        }
      ];
    };
}
