# Shared profile for the four virtual hosts (buzz, jessie, mrpotatohead,
# pricklepants): everything the qemu-style guests repeat verbatim today,
# extracted under ADR-0015. Physical hosts (lenny, rex, slinky, woody, zurg)
# import not-detected.nix instead and do not use this profile.
{
  flake.modules.nixos.vps-guest =
    { modulesPath, ... }:
    {
      imports = [
        (modulesPath + "/profiles/minimal.nix")
        (modulesPath + "/profiles/headless.nix")
      ];

      security.sudo.extraConfig = ''
        # rollback results in sudo lectures after each reboot
        Defaults lecture = never
      '';

      # rolls this host back to the previous generation and reboots it when systemd
      # reports a failed unit one settle delay after switch-to-configuration
      upgradeHealth.enable = true;
    };
}
