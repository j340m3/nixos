# Host aspect (ADR 0014): the module list is assembled by lib.mkNixos
# (modules/nix/lib.nix) from flake.modules.nixos.lenny; the flake-parts.nix
# one-liner next to this file declares the host into the flake.
# inputs/constants close over the head args. Two-file host: the hardware
# scan result and the former boot specialisations are inlined below — no
# host-local glue.
{ inputs, lib, ... }:

{
  flake.modules.nixos.lenny =
    {
      modulesPath,
      config,
      pkgs,
      lib,
      ...
    }:
    {
      imports = [
        inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x230
        #<nixos-hardware/lenovo/thinkpad/x230>
        (modulesPath + "/installer/scan/not-detected.nix")
        inputs.self.modules.nixos.system-default
        inputs.self.modules.nixos.logging
        inputs.self.modules.nixos.nebula
        inputs.self.modules.nixos.wifi
        inputs.chaotic.nixosModules.default
      ];

      # Inlined from ./_hardware-configuration.nix, ./jeromeb/_default.nix and
      # ./lilly/_default.nix (zero host-local glue, ADR 0014): hardware scan
      # result plus the two former boot specialisations (system.nixos.tags
      # keeps both, so both generations stay bootable).
      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "ehci_pci"
        "ahci"
        "usb_storage"
        "sd_mod"
        "sdhci_pci"
      ];
      boot.kernelModules = [ "kvm-intel" ];

      fileSystems."/" = {
        device = "/dev/disk/by-uuid/df7c48e8-8f72-41ec-96fe-1640260df2da";
        fsType = "ext4";
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/0e33458d-bdbe-4354-bba0-345b1486dfc7";
        fsType = "ext4";
      };

      # Enables DHCP on each ethernet and wireless interface.
      networking.useDHCP = lib.mkDefault true;
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

      # Former ./jeromeb/_default.nix ("jeromeb"s boot entry).
      nixpkgs.overlays = [
        inputs.affinity-nix.overlays.default
      ];
      users.mutableUsers = false;
      system.nixos.tags = [ "jeromeb" "lilly" ];
      users.users.jeromeb = {
        isNormalUser = true;
        description = "Jerome Bergmann";
        extraGroups = [
          "networkmanager"
          "wheel"
        ];
        hashedPassword = "$y$j9T$xI3Gvnwn4Q900uL0HQZHp/$fl5oFfnZWZWBz.6gPxvciND13komHHAXDqq6Yfpjn17";
        uid = 1002;
        packages = with pkgs; [
          firefox
          affinity-v3
        ];
      };
      # Former ./lilly/_default.nix ("lilly" boot entry).
      users.users.lilly = {
        hashedPassword = "$y$j9T$9nhgpZ1ZGEPdJW.NDaBZN/$Gpo9WnS8B8zGj9Ax19PRa2IdZSIxrkBKYLISRNsvd53";
        uid = 1001;
        isNormalUser = true;
        description = "Lilly Bergmann";
        extraGroups = [
          "networkmanager"
          "wheel"
        ];
        packages = with pkgs; [
          tipp10
          libreoffice-qt
          anki
          jetbrains.pycharm-oss
          pinta
          krita
          arduino
          lynx
          #  kdenlive
          signal-cli
          signal-desktop
          firefox
          kdePackages.kalk
          spotify
          cutechess
          stockfish
          luanti
          flatpak
          #  kalk
          #  kate
          #  thunderbird
        ];
      };
      services.flatpak.enable = true;
      systemd.services.flatpak-repo = {
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.flatpak ];
        script = ''
          flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        '';
      };

      # jeromeb's home, wired into the host rebuild instead of a standalone switch
      home-manager.users.jeromeb.imports = [ inputs.self.modules.homeManager.jeromeb ];

      # Bootloader.
      boot.loader.grub.enable = true;
      boot.loader.grub.device = "/dev/sda";
      boot.loader.grub.useOSProber = true;

      boot.kernelPackages = pkgs.linuxPackages_cachyos-lts;

      swapDevices = [
        {
          device = "/swapfile";
          size = 2048;
        }
      ];
      boot.tmp.cleanOnBoot = true;
      zramSwap.enable = true;

      networking.hostName = "lenny"; # Define your hostname.
      # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

      # Configure network proxy if necessary
      # networking.proxy.default = "http://user:password@proxy:port/";
      # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

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

      # Enable the X11 windowing system.
      services.xserver.enable = true;
      xdg.portal.enable = true;
      xdg.portal.extraPortals = [
        pkgs.xdg-desktop-portal-gtk
      ];

      # Configure keymap in X11
      services.xserver.xkb = {
        layout = "de";
        variant = "";
      };

      # Configure console keymap
      console.keyMap = "de";

      # Enable CUPS to print documents.
      services.printing.enable = true;

      # Enable sound with pipewire.
      # sound.enable = true;
      hardware.bluetooth.enable = true; # enables support for Bluetooth
      hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot
      services.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        # If you want to use JACK applications, uncomment this
        #jack.enable = true;

        # use the example session manager (no others are packaged yet so this is enabled by default,
        # no need to redefine it in your config for now)
        #media-session.enable = true;
      };

      # Enable touchpad support (enabled default in most desktopManager).
      # services.xserver.libinput.enable = true;

      # Define a user account. Don't forget to set a password with ‘passwd’.

      # Allow unfree packages
      nixpkgs.config.allowUnfree = true;
      nixpkgs.config.permittedInsecurePackages = [
        "pycharm-oss-2025.3.3"
      ];

      # List packages installed in system profile. To search, run:
      # $ nix search wget
      environment.systemPackages = [
        #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
        #  wget
        pkgs.hunspell
        pkgs.hunspellDicts.de_DE
        pkgs.cifs-utils
        pkgs.htop
        pkgs.kdePackages.discover
      ];

      # Some programs need SUID wrappers, can be configured further or are
      # started in user sessions.
      # programs.mtr.enable = true;
      # programs.gnupg.agent = {
      #   enable = true;
      #   enableSSHSupport = true;
      # };

      # List services that you want to enable:

      # Enable the OpenSSH daemon.
      # Settings (port, no password login, no root login, AllowGroups) come from
      # modules/_common/ssh.nix. Do not re-enable password/root login here.
      services.openssh.enable = true;
      # Open ports in the firewall.
      # networking.firewall.allowedTCPPorts = [ ... ];
      # networking.firewall.allowedUDPPorts = [ ... ];
      # Or disable the firewall altogether.
      # networking.firewall.enable = false;

      # This value determines the NixOS release from which the default
      # settings for stateful data, like file locations and database versions
      # on your system were taken. It‘s perfectly fine and recommended to leave
      # this value at the release version of the first install of this system.
      # Before changing this value read the documentation for this option
      # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
      system.stateVersion = "23.11"; # Did you read the comment?

      services.clamav.daemon.enable = true;
      services.clamav.updater.enable = true;

      fileSystems."/mnt/share" = {
        device = "//bergmannnas/home";
        fsType = "cifs";
        #label = "NAS";
        options =
          let
            # this line prevents hanging on network split
            automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";

          in
          [ "${automount_opts},credentials=/etc/nixos/smb-secrets,uid=1001,gid=100" ];
      };

      # 2024-08-11 Garbage Collection
      nix.gc.automatic = true;
      nix.gc.dates = "daily";
      nix.gc.options = "--delete-older-than 20d";

    };
}
