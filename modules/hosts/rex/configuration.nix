# Host aspect (ADR 0014): the module list is assembled by lib.mkNixos
# (modules/nix/lib.nix) from flake.modules.nixos.rex; the flake-parts.nix
# one-liner next to this file declares the host into the flake.
# inputs/constants close over the head args. Two-file host: the hardware
# scan result is inlined below — no host-local glue.
# -----------------------------------------------------------------------------
# Rex - My laptop at work
# -----------------------------------------------------------------------------
{ inputs, lib, ... }:

let
  constants = import ../../../modules/global/_constants.nix;
in
{
  flake.modules.nixos.rex =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      imports = [
        inputs.self.modules.nixos.jeromeb
        inputs.self.modules.nixos.xfce
        inputs.self.modules.nixos.system-default
        inputs.self.modules.nixos.logging
        inputs.self.modules.nixos.nebula
        # home-manager module comes in via modules/_common/home-manager.nix
      ];

      # Inlined from ./_hardware-configuration.nix (zero host-local glue, ADR 0014).
      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "ahci"
        "sd_mod"
      ];

      fileSystems."/" = {
        device = "/dev/disk/by-uuid/ab0899ec-d5b7-4642-be38-577ac223712d";
        fsType = "ext4";
        autoResize = true;
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/3B75-1995";
        fsType = "vfat";
        options = [
          "fmask=0077"
          "dmask=0077"
        ];
      };

      virtualisation.virtualbox.guest.enable = true;

      # jeromeb's home, wired into the host rebuild instead of a standalone switch
      home-manager.users.jeromeb.imports = [ inputs.self.modules.homeManager.jeromeb ];

      # Bootloader.
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;

      boot.extraModulePackages = with config.boot.kernelPackages; [ virtualboxGuestAdditions ];
      # D&D helper is a systemd USER unit (virtualbox-guest.nix
      # mkIf cfg.dragAndDrop); the host never exposes the HGCM service, so
      # it dies with VERR_HGCM_SERVICE_NOT_FOUND and restart-loops forever
      # (counter 2717 by 2026-11-05). Disabling the option is the real fix —
      # a systemd.services override only creates a bogus SYSTEM unit.
      virtualisation.virtualbox.guest.dragAndDrop = false;
      #boot.kernelPackages = pkgs.linuxPackages_cachyos;

      zramSwap.enable = true;
      virtualisation.diskSize = "auto";
      #virtualisation.additionalSpace = "5G";
      boot.growPartition = true;

      networking.hostName = "rex"; # Define your hostname.

      # Enable networking
      networking.networkmanager.enable = true;

      # Enable sound with pipewire.
      services.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };

      allowReboot = false;
      #useComin = true;
      virtualisation.docker.enable = true;
      # Define a user account. Don't forget to set a password with ‘passwd’.
      #stylix.homeManagerIntegration.followSystem = false;
      #stylix.homeManagerIntegration.autoImport = false;
      # home-manager.useGlobalPkgs = true;

      # Allow unfree packages
      #nixpkgs.config.allowUnfree = true;

      environment.systemPackages = with pkgs; [
        powerline-fonts
        powerline-symbols
        nebula
        exfat
        zabbix.agent
        #exfatprogs

      ];

      system.stateVersion = "24.11";

      nix.settings.auto-optimise-store = true;

      #nixpkgs.config.packageOverrides = pkgs: {
      #  nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") {
      #    inherit pkgs;
      #  };
      #};

      networking.nameservers = [
        "${constants.host.woody.ip}"
        "1.1.1.1"
        "8.8.8.8"
        "9.9.9.9"
      ];
      networking.useDHCP = lib.mkForce true;
    };
}
