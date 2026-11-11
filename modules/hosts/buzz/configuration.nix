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
      lib,
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
        # nebula via the lighthouse flavor (roster-derived am_lighthouse); it
        # also brings the remote-build accept side
        inputs.self.modules.nixos.nebula-lighthouse
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

      # Lighthouse flavor comes from inputs.self.modules.nixos.nebula-lighthouse
      # (roster-derived); what stays host-local:
      services.nebula.networks.mesh = {
        # drift vs. the shared aspect (punchy.respond): reload makes nebula
        # reload its certificate on change — kept verbatim, unify as follow-up
        settings.punchy = lib.mkForce {
          punch = true;
          reload = true;
        };
        # serve DNS over the mesh for fleet members; claimed from
        # systemd-resolved via the firewall rules below
        lighthouse.dns.host = "0.0.0.0";
        lighthouse.dns.port = 53;
        # lighthouse-only mesh surfaces: DNS + the zabbix proxy agent
        firewall.inbound = [
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
        ];
      };
      # cert/key material lives on the persistent btrfs root
      mesh.nebulaSecretDir = "/nix/persist/etc/nebula";

      # allow nebula to claim port 53 from systemd-resolved
      #services.resolved.extraConfig = ''
      #  DNSStubListener=no
      #'';
      # open the systems firewall for DNS on the nebula interface and public interfaces
      networking.firewall.interfaces."nebula.mesh".allowedUDPPorts = [ 53 ];
      networking.firewall.allowedUDPPorts = [ 53 ];

      # upgradeHealth.enable = true comes from inputs.self.modules.nixos.vps-guest.
    };
}
