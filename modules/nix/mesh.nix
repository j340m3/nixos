# Carrier for mesh-wide knobs (ADR 0015): every host gets the option
# definitions via lib.mkNixos (modules/nix/lib.nix), so feature modules
# (ssh, comin, grafana, …) can contribute mesh ports even on hosts that do
# not import the nebula aspect directly. The nebula aspect
# (modules/services/nebula.nix) consumes the collected list and renders
# the inbound firewall rules.
_: {
  flake.modules.nixos.mesh-ports =
    { lib, ... }:
    {
      options.mesh.openInbound = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            port = lib.mkOption {
              type = lib.types.either lib.types.int lib.types.str;
              description = "Port number, or the literal string \"any\".";
            };
            proto = lib.mkOption {
              type = lib.types.str;
              default = "any";
              description = "Protocol the rule matches (any/tcp/udp/icmp).";
            };
          };
        });
        default = [ ];
        description = ''
          Ports this host exposes on the nebula mesh, collected from the
          feature modules and rendered as inbound rules for the mesh CIDR by
          modules/services/nebula.nix.
        '';
      };

      options.mesh.nebulaSecretDir = lib.mkOption {
        type = lib.types.str;
        default = "/etc/nebula";
        description = ''
          Directory the nebula aspect (modules/services/nebula.nix) writes its
          sops-managed cert/key material to. Hosts whose /etc is ephemeral
          (buzz, pricklepants) point this at /nix/persist/etc/nebula so the
          material survives reboots.
        '';
      };
    };
}
