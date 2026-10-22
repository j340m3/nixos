# Host aspect (ADR 0014): flake.modules.nixos.sid is assembled by lib.mkNixos
# (modules/nix/lib.nix); the flake-parts.nix one-liner next to this file
# declares the host into the flake. inputs arrive via the transitional
# specialArgs in the factory, so the head args stay verbatim.
{ lib, ... }:

{
  flake.modules.nixos.sid =
    {
      config,
      lib,
      pkgs,
      inputs,
      ...
    }:
    {
      imports = [
        # include NixOS-WSL modules
        #<nixos-wsl/modules>
        inputs.nixos-wsl.nixosModules.default
        inputs.self.modules.nixos.agent-md
        ./_editor.nix
        ./_nvidia.nix
      ];

      environment.systemPackages = [
        pkgs.qownnotes
      ];

      networking.hostName = "sid";
      nixpkgs.hostPlatform = "x86_64-linux";
      wsl.enable = true;
      wsl.defaultUser = "nixos";
      wsl.useWindowsDriver = true;
      nixpkgs.config.allowUnfree = true;

      # This value determines the NixOS release from which the default
      # settings for stateful data, like file locations and database versions
      # on your system were taken. It's perfectly fine and recommended to leave
      # this value at the release version of the first install of this system.
      # Before changing this value read the documentation for this option
      # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
      system.stateVersion = "25.05"; # Did you read the comment?
    };
}
