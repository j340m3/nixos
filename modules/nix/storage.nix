# Carrier for the host storage tier (improvement session 2026-11-12): the
# tier is a host fact, so the roster lives in modules/global/_constants.nix
# next to the other per-host facts (monitor flags, mesh IPs). Consumers:
# the per-tier user-app kit (modules/home/jeromeb.nix) and any future
# storage policy. The option is factory-wired (modules/nix/lib.nix) so every
# host gets it whether or not it imports system-default.
let
  constants = import ../global/_constants.nix;
in
{
  flake.modules.nixos.storage-opts =
    { config, lib, ... }:
    {
      options.storage.tier = lib.mkOption {
        type = lib.types.enum [
          "small"
          "medium"
          "large"
          "tierless"
        ];
        # Roster default; a host may still override it locally.
        default = constants.storageTier.${config.networking.hostName} or "tierless";
        description = ''
          Disk-size class of this host. Drives the per-tier user-app kit
          (small = CLI only, medium = + messaging, large = full desktop
          kit) and is the place future storage policy keys off. tierless
          means "no app kit decision" (sid is WSL on a Windows-side disk;
          the bootstrap hosts are throwaway).
        '';
      };
    };
}
