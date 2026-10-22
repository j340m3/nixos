{ inputs, ... }:
let
  constants = import (inputs.self + "/global/constants.nix");
in
{
  flake.modules.nixos.grafana =
    {
      config,
      lib,
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
      };

      # 26.05 asserts settings.security.secret_key != null at eval time. The key
      # itself lives in the sops-managed dotenv below and reaches grafana as the
      # GF_SECURITY_SECRET_KEY environment variable, so hand grafana its env
      # provider rather than putting a secret anywhere in the nix store.
      services.grafana.settings.security.secret_key = "$__env{GF_SECURITY_SECRET_KEY}";

      # Inject secrets as environment variables: GF_SECURITY_* override the INI.
      # The decrypted secret is a dotenv-style file:
      #   GF_SECURITY_ADMIN_PASSWORD=...
      #   GF_SECURITY_SECRET_KEY=...
      sops.secrets."grafana-env" = {
        sopsFile = ../../secrets/hosts/woody/services.yaml;
        restartUnits = [ "grafana.service" ];
      };
      systemd.services.grafana.serviceConfig.EnvironmentFile = config.sops.secrets."grafana-env".path;
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
    };
}
