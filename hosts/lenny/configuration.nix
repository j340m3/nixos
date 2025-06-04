## Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      #inputs.nixos-hardware.lenovo-thinkpad-x230
      #<nixos-hardware/lenovo/thinkpad/x230>
      ./hardware-configuration.nix
      ../common.nix
      ../../modules/logging.nix
      ../../modules/nebula.nix
      ../../modules/zabbix.nix
    ];

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  boot.kernelPackages = pkgs.linuxPackages_zen;

  swapDevices = [ { device = "/swapfile"; size = 2048; } ];
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

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

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
  users.users.jeromeb = {
    isNormalUser = true;
    description = "Jerome Bergmann";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      firefox
    #  kate
    #  thunderbird
    ];
  };

 /*  users.users.emelie = {
    isNormalUser = true;
    description = "Emelie Bergmann";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      firefox
    #  kate
    #  thunderbird
    ];
  }; */

  users.users.lilly = {
    isNormalUser = true;
    description = "Lilly Bergmann";
    extraGroups = [ ];
    packages = with pkgs; [
      tipp10
      libreoffice-qt
      anki
      jetbrains.pycharm-community
      pinta
      krita
      arduino
      lynx
    #  kdenlive
      signal-desktop
      (makeAutostartItem { name = "signal"; package = signal-desktop; })
      firefox
      kdePackages.kalk
      spotify
      cutechess
      stockfish
      minetest
    #  kalk
    #  kate
    #  thunderbird
    ];
  };
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
    hunspell
    hunspellDicts.de_DE
    python3Full
    python3Packages.pip
    python3Packages.setuptools
    cifs-utils
    pkgs.signaldctl
    htop
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
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = lib.mkForce "yes";
  services.openssh.settings.PasswordAuthentication = lib.mkForce true;
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
  system.autoUpgrade.enable = true;

  /* services.signald = {
    enable = true;
    user = "lilly";
  }; */
  services.clamav.daemon.enable = true;
  services.clamav.updater.enable = true;

  fileSystems."/mnt/share" = {
      device = "//bergmannnas/home";
      fsType = "cifs";
      #label = "NAS";
      options = let
        # this line prevents hanging on network split
        automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";

      in ["${automount_opts},credentials=/etc/nixos/smb-secrets,uid=1001,gid=100"];
  };


  # 2024-08-11 Garbage Collection
  nix.gc.automatic = true;
  nix.gc.dates = "daily";
  nix.gc.options = "--delete-older-than 20d";
  nix.extraOptions = ''
                      min-free = ${toString (100 * 1024 * 1024)}
                      max-free = ${toString (1024 * 1024 * 1024)}
                     '';

  /* services.nebula.networks.mesh = {
    enable = true;
    isLighthouse = false;
    lighthouses = [ "10.0.0.1" ];
    settings = {
        cipher= "aes";
        punchy.punch=true;
        };
    cert = "/etc/nebula/lenny.crt";
    key = "/etc/nebula/lenny.key";
    ca = "/etc/nebula/ca.crt";
    staticHostMap = {
        "10.0.0.1" = [
                "194.164.125.154:4242"
                ];
        };
    firewall.outbound = [
  {
    host = "any";
    port = "any";
    proto = "any";
  }
];
    firewall.inbound = [
  {
    host = "any";
    port = "any";
    proto = "any";
  }
];
  }; */

/* services.zabbixAgent = {
    enable = true;
    openFirewall = true;
    server = "10.0.0.3";
    settings = {
      Hostname = "lenny";
    };
  }; */
}
