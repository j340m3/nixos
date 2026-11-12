# Host aspect (ADR 0014): flake.modules.nixos.bootstrap-impermanent is assembled by lib.mkNixos
# (modules/nix/lib.nix); the flake-parts.nix one-liner next to this file
# declares the host into the flake. inputs arrive via the transitional
# specialArgs in the factory, so the head args stay verbatim.
#
# Uses the tmpfs-root layout (impermanence); the shared head comes from
# bootstrap-core. The deltas vs bootstrap-base live here: nameservers,
# ssh port, hostname and the root rescue password.
# Root SSH is off (PermitRootLogin no); admin access is the donquezz
# aspect (wheel) over ssh — the shared 2222 port for first contact.
{ inputs, lib, ... }:
{
  flake.modules.nixos.bootstrap-impermanent =
    {
      lib,
      pkgs,
      ...
    }:
    {
      imports = [
        inputs.self.modules.nixos.bootstrap-core
        inputs.self.modules.nixos.bootstrap-tmpfs-root
        inputs.self.modules.nixos.donquezz
      ];

      networking.nameservers = [
        "8.8.8.8"
      ];

      # Enable SSH server and listen on port 2222
      services.openssh.ports = lib.mkDefault [ 2222 ];

      # Hostname, can be set as you wish
      networking.hostName = lib.mkDefault "bootstrap-impermanent";

      # Root password for serial-console/VNC rescue only (not a network
      # surface: PermitRootLogin no, PasswordAuthentication false). If
      # network config is incorrect, use this password to manually adjust
      # network config on serial console/VNC.
      services.openssh.settings.PermitRootLogin = "no";
      users.mutableUsers = false;
      users.users.root.hashedPassword = "$y$j9T$xI3Gvnwn4Q900uL0HQZHp/$fl5oFfnZWZWBz.6gPxvciND13komHHAXDqq6Yfpjn17";
      users.users.root.packages = with pkgs; [
        openssl
      ];
    };
}
