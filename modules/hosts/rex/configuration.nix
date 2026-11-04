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
        inputs.chaotic.nixosModules.default
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

      boot.kernelPackages = pkgs.linuxPackages_cachyos-lto;
      boot.extraModulePackages = with config.boot.kernelPackages; [ virtualboxGuestAdditions ];
      systemd.services."virtualboxClientDragAndDrop" = {
        wantedBy = lib.mkForce [ ]; # Disable Drag and Drop
        #execStart=lib.mkForce [""];
      };
      #boot.kernelPackages = pkgs.linuxPackages_cachyos;

      boot.tmp.cleanOnBoot = true;
      zramSwap.enable = true;
      virtualisation.diskSize = "auto";
      #virtualisation.additionalSpace = "5G";
      boot.growPartition = true;

      networking.hostName = "rex"; # Define your hostname.

      # Enable networking
      networking.networkmanager.enable = true;

      # Set your time zone.
      time.timeZone = "Europe/Berlin";

      # Select internationalisation properties.
      i18n.defaultLocale = "de_DE.UTF-8";

      i18n.extraLocaleSettings = {
        LC_ADDRESS = "de_DE.UTF-8";
        LC_IDENTIFICATION = "de_DE.UTF-8";
        LC_MEASUREMENT = "de_DE.UTF-8";
        LC_MONETARY = "de_DE.UTF-8";
        LC_NAME = "de_DE.UTF-8";
        LC_NUMERIC = "de_DE.UTF-8";
        LC_PAPER = "de_DE.UTF-8";
        LC_TELEPHONE = "de_DE.UTF-8";
        LC_TIME = "de_DE.UTF-8";
      };

      # Configure keymap in X11
      services.xserver.xkb = {
        layout = "de";
        variant = "";
      };

      # Configure console keymap
      console.keyMap = "de";

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
