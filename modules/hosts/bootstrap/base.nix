# bootstrap-base = bootstrap-core + the btrfs-root disk layout + the
# donquezz aspect: the profile imported by the `bootstrap` host (and by
# buzz). The tmpfs-root variant for the impermanent image lives in
# tmpfs-root.nix and is used by bootstrap-impermanent instead.
{ inputs, ... }:
let
  constants = import ../../global/_constants.nix;
in
{
  flake.modules.nixos.bootstrap-base =
    {
      pkgs,
      lib,
      ...
    }:
    {
      imports = [
        inputs.self.modules.nixos.bootstrap-core
        inputs.self.modules.nixos.bootstrap-btrfs-root
        inputs.self.modules.nixos.donquezz
      ];
      environment.systemPackages = with pkgs; [
        git
      ];
      # Configure DNS
      networking.nameservers = [
        "1.1.1.1"
      ];
      # Enable SSH server and listen on the shared bootstrap port
      services.openssh.ports = lib.mkDefault [ constants.sshPort ];
      # Hostname, can be set as you wish
      networking.hostName = lib.mkDefault "bootstrap";
      # Root password and SSH keys. If network config is incorrect, use this password
      # to manually adjust network config on serial console/VNC.
      # Root SSH is off fleet-wide (PermitRootLogin no via the ssh aspect);
      # root rescue on this host is the serial console.
      /*
        services.swapspace.enable = true;
        services.swapspace.settings = {
          swappath="/nix/swapfile";
          lower_freelimit=50;
          upper_freelimit=70;
          freetarget=60;
          buffer_elasticity=100;
          cache_elasticity=100;
        };
        boot.kernel.sysctl = { "vm.swappiness" = lib.mkDefault 5;};
      */
    };
}
