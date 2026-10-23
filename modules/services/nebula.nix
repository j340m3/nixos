{ inputs, ... }:
let
  constants = import ../global/_constants.nix;
in
{
  flake.modules.nixos.nebula =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # lighthouse status rides the roster (inline nebula hosts set their own)
      isLighthouse = builtins.elem config.networking.hostName constants.lighthouses;
      # a host must never list itself as lighthouse/relay: nebula requires every
      # entry to have a static_host_map entry, and constants.nebula.staticMap
      # (correctly) omits self. Self-listing made nebula crash-loop on jessie and
      # mrpotatohead from 2026-10-17 (fatal "lighthouse X does not have a
      # static_host_map entry") and aborted every subsequent switch with
      # switch-to-configuration exit 4.
      notSelf = h: h != config.networking.hostName;
    in
    {
      # Mesh member => remote-build accept side (every mesh host builds for the
      # fleet). The two lighthouses (pricklepants, buzz) define nebula inline in
      # their host files, so they import the remote-builder aspect there.
      imports = [ inputs.self.modules.nixos.remote-builder ];

      environment.systemPackages = with pkgs; [
        nebula
      ];

      services.nebula.networks.mesh = {
        listen.host = "[::]";
        enable = true;
        inherit isLighthouse;
        # roster in modules/global/_constants.nix: names -> mesh ip + public endpoints
        lighthouses = map (h: constants.host.${h}.ip) (builtins.filter notSelf constants.lighthouses);
        relays = map (h: constants.host.${h}.ip) (builtins.filter notSelf constants.lighthouses);
        settings = {
          cipher = "aes";
          static_map = {
            network = "ip";
          };
          punchy = {
            punch = true;
            respond = true;
          };
          dns = {
            host = constants.host.${constants.nebula.dns}.ip;
            port = 53;
          };
        };
        cert = config.sops.secrets."nebula/self_crt".path; # "/run/secrets/nebula/self.crt";
        key = config.sops.secrets."nebula/self_key".path; # "/run/secrets/nebula/self.key";
        ca = config.sops.secrets."nebula/ca_crt".path; # "/run/secrets/nebula/ca.crt";
        staticHostMap = constants.nebula.staticMap config.networking.hostName;
        firewall.outbound = [
          {
            cidr = constants.nebula.cidr;
            port = "any";
            proto = "any";
          }
        ];

        firewall.inbound = [
          {
            cidr = constants.nebula.cidr;
            proto = "icmp";
            port = "any";
          }
          /*
            {
              cidr = constants.nebula.cidr;
              port = "any";
              proto = "any";
            }
          */
        ];
        /*
          {
            cidr = constants.nebula.cidr;
            port = "any";
            proto = "any";
          }]
          ++ lib.optional (config.useComin) ({
            cidr = constants.nebula.cidr;
            port = "4242";
            proto = "any";
          });
        */

      };
      # module-managed lighthouses accept WAN peerings; the two inline nebula
      # hosts (pricklepants, buzz) don't import this module
      networking.firewall.allowedUDPPorts = lib.mkIf isLighthouse [ constants.nebula.port ];

      sops.secrets."nebula/ca_crt" = {
        restartUnits = [ "nebula@mesh.service" ];
        owner = "nebula-mesh";
        group = "nebula-mesh";
        path = "/etc/nebula/ca.crt";
      };
      sops.secrets."nebula/self_crt" = {
        sopsFile = ../../secrets/hosts/${config.networking.hostName}/secrets.yaml;
        restartUnits = [ "nebula@mesh.service" ];
        owner = "nebula-mesh";
        group = "nebula-mesh";
        path = "/etc/nebula/self.crt";
      };
      sops.secrets."nebula/self_key" = {
        sopsFile = ../../secrets/hosts/${config.networking.hostName}/secrets.yaml;
        restartUnits = [ "nebula@mesh.service" ];
        owner = "nebula-mesh";
        group = "nebula-mesh";
        path = "/etc/nebula/self.key";
      };
    };
}
