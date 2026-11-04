# Host aspect (ADR 0014): flake.modules.nixos.buzz is assembled by lib.mkNixos
# (modules/nix/lib.nix); the flake-parts.nix one-liner next to this file
# declares the host into the flake. inputs/constants arrive via the
# transitional specialArgs in the factory, so the head args stay verbatim.
{ inputs, lib, ... }:

let
  constants = import ../../../modules/global/_constants.nix;
in
{
  flake.modules.nixos.buzz =
    {
      config,
      lib,
      pkgs,
      modulesPath,
      ...
    }:
    {
      imports = [
        inputs.self.modules.nixos.bootstrap-base
        (modulesPath + "/profiles/minimal.nix")
        (modulesPath + "/profiles/headless.nix")
        inputs.self.modules.nixos.vps-guest
        inputs.self.modules.nixos.acme
        inputs.self.modules.nixos.system-default
        inputs.self.modules.nixos.donquezz
        inputs.self.modules.nixos.logging
        # nextcloud lives on mrpotatohead (public DNS nextcloud.kauderwels.ch +
        # files.dabergmann.de both point there); a second instance here would
        # fight it over ACME identity and sops secrets when buzz returns
        inputs.self.modules.nixos.wireguard
        inputs.self.modules.nixos.pihole
        # nebula config is defined inline below (this host is a lighthouse);
        # pull in the remote-build accept side that other mesh members get via modules/_nebula.nix
        inputs.self.modules.nixos.remote-builder
      ];

      # Use the GRUB 2 boot loader.
      boot.loader.grub.enable = true;
      zramSwap.memoryPercent = 20;
      nix.gc.dates = lib.mkForce "hourly";
      nix.gc.options = lib.mkForce "-d";

      networking.hostName = "buzz"; # Define your hostname.
      # Ionos uplink NIC is ens6 (not eth0), so the WireGuard NAT masquerade binds correctly.
      networking.nat.externalInterface = "ens6";
      networking.firewall.enable = true;

      system.stateVersion = "25.05";

      environment.systemPackages = with pkgs; [
        nebula
      ];

      services.nebula.networks.mesh = {
        enable = true;
        isLighthouse = true;
        isRelay = true;
        cert = config.sops.secrets."nebula/self_crt".path; # "/run/secrets/nebula/self.crt";
        key = config.sops.secrets."nebula/self_key".path; # "/run/secrets/nebula/self.key";
        ca = config.sops.secrets."nebula/ca_crt".path; # "/run/secrets/nebula/ca.crt";
        # staticHostMap (other lighthouse) comes from modules/global/_constants.nix.
        staticHostMap = constants.nebula.staticMap config.networking.hostName;
        settings = {
          lighthouse = {
            serve_dns = false;
            dns = {
              host = "0.0.0.0";
              port = 53;
            };
          };
          static_map = {
            network = "ip";
          };
          cipher = "aes";
          punchy = {
            punch = true;
            reload = true;
          };
        };
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
            port = "any";
            proto = "icmp";
          }
          {
            cidr = constants.nebula.cidr;
            port = "53";
            proto = "udp";
          }
          {
            cidr = constants.nebula.cidr;
            port = "10050";
            proto = "any";
          }
          {
            cidr = constants.nebula.cidr;
            port = "42069";
            proto = "tcp";
          }
        ];
      };

      systemd.services."nebula@mesh".serviceConfig = {
        CapabilityBoundingSet = lib.mkForce "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
        AmbientCapabilities = lib.mkForce "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
      };
      # allow nebula to claim port 53 from systemd-resolved
      #services.resolved.extraConfig = ''
      #  DNSStubListener=no
      #'';
      # open the systems firewall for DNS on the nebula interface and public interfaces
      networking.firewall.interfaces."nebula.mesh".allowedUDPPorts = [ 53 ];
      networking.firewall.allowedUDPPorts = [ 53 ];

      sops.secrets."nebula/ca_crt" = {
        restartUnits = [ "nebula@mesh.service" ];
        owner = "nebula-mesh";
        group = "nebula-mesh";
        path = "/nix/persist/etc/nebula/ca.crt";
      };
      sops.secrets."nebula/self_crt" = {
        sopsFile = ../../../secrets/hosts/${config.networking.hostName}/secrets.yaml;
        restartUnits = [ "nebula@mesh.service" ];
        owner = "nebula-mesh";
        group = "nebula-mesh";
        path = "/nix/persist/etc/nebula/self.crt";
      };
      sops.secrets."nebula/self_key" = {
        sopsFile = ../../../secrets/hosts/${config.networking.hostName}/secrets.yaml;
        restartUnits = [ "nebula@mesh.service" ];
        owner = "nebula-mesh";
        group = "nebula-mesh";
        path = "/nix/persist/etc/nebula/self.key";
      };

      # upgradeHealth.enable = true comes from inputs.self.modules.nixos.vps-guest.
    };
}
