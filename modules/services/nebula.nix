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
      # lighthouse status rides the roster (see the nebula-lighthouse flavor
      # below for the hosts that used to configure nebula inline)
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
      # fleet). The nebula-lighthouse flavor below inherits this import.
      imports = [ inputs.self.modules.nixos.remote-builder ];

      environment.systemPackages = with pkgs; [
        nebula
      ];

      services.nebula.networks.mesh = {
        # mkDefault so the nebula-lighthouse flavor can keep its verbatim
        # v4-only listen host
        listen.host = lib.mkDefault "[::]";
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

        firewall.inbound =
          [
            {
              cidr = constants.nebula.cidr;
              proto = "icmp";
              port = "any";
            }
          ]
          # Feature modules contribute their mesh surfaces via mesh.openInbound
          # (carrier: modules/nix/mesh.nix); order follows their definition
          # order. Allow-rules only, so reordering vs. the old per-module
          # inline lists is semantically neutral.
          ++ map (r: {
            cidr = constants.nebula.cidr;
            inherit (r) port proto;
          }) config.mesh.openInbound;

      };
      # open the mesh UDP port on ALL module-managed hosts, not just
      # lighthouses: peers must be able to initiate handshakes directly even
      # when NAT reply-state died (woody<->pricklepants handshake deadlock
      # after the 2026-11-03 restarts: 24k sent / 24k timed out / 1 received
      # over three days while pricklepants' replies never made it back).
      networking.firewall.allowedUDPPorts = [ constants.nebula.port ];

      sops.secrets."nebula/ca_crt" = {
        restartUnits = [ "nebula@mesh.service" ];
        owner = "nebula-mesh";
        group = "nebula-mesh";
        path = "${config.mesh.nebulaSecretDir}/ca.crt";
      };
      sops.secrets."nebula/self_crt" = {
        sopsFile = ../../secrets/hosts/${config.networking.hostName}/secrets.yaml;
        restartUnits = [ "nebula@mesh.service" ];
        owner = "nebula-mesh";
        group = "nebula-mesh";
        path = "${config.mesh.nebulaSecretDir}/self.crt";
      };
      sops.secrets."nebula/self_key" = {
        sopsFile = ../../secrets/hosts/${config.networking.hostName}/secrets.yaml;
        restartUnits = [ "nebula@mesh.service" ];
        owner = "nebula-mesh";
        group = "nebula-mesh";
        path = "${config.mesh.nebulaSecretDir}/self.key";
      };
    };

  # Lighthouse flavor for the hosts that used to carry their nebula config
  # inline (buzz, pricklepants): same aspect underneath, but the rendered
  # config stays byte-for-byte what those hosts had — no lighthouse/relay
  # lists (upstream ignores them on am_lighthouse nodes anyway), relay
  # enabled, v4-only listen host, and the forced capability set. Per-host
  # leftovers (punchy drift, DNS serving, mesh inbound ports, secret dir)
  # live in the host files.
  flake.modules.nixos.nebula-lighthouse =
    { lib, ... }:
    {
      imports = [ inputs.self.modules.nixos.nebula ];
      services.nebula.networks.mesh = {
        isRelay = true;
        lighthouses = lib.mkForce [ ];
        relays = lib.mkForce [ ];
        listen.host = "0.0.0.0";
      };
      systemd.services."nebula@mesh".serviceConfig = {
        CapabilityBoundingSet = lib.mkForce "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
        AmbientCapabilities = lib.mkForce "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
      };
    };
}
