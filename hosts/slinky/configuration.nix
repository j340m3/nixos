# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  config,
  lib,
  pkgs,
  ...
}: {
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      # Include uConsole settings
      ./uConsole.nix
      ../common.nix
      ../../modules/vscodium.nix
    ]
    ++ lib.optional (builtins.pathExists ./local.nix) ./local.nix;

  # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;

  networking.hostName = "slinky"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "de_DE.UTF-8";
  #console = {
  #  font = "Lat2-Terminus16";
  #  keyMap = "us";
  #  useXkbConfig = true; # use xkb.options in tty.
  #};

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
  services.displayManager.defaultSession = "xfce";
  services.displayManager.sddm.enable = true;
  services.displayManager.autoLogin = {
    enable = true;
    user = "j340m3";
  };
  #services.displayManager.sddm.wayland.enable = true;
  #services.displayManager.sddm.wayland.compositor = "weston";
  #services.xserver.displayManager.sddm.enable = true;
  # Configure keymap in X11
  services.xserver.xkb.layout = "us";
  services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # hardware.pulseaudio.enable = true;
  # OR
  # services.pipewire = {
  #   enable = true;
  #   pulse.enable = true;
  # };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users.alice = {
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  #   packages = with pkgs; [
  #     firefox
  #     tree
  #   ];
  # };

 # programs.hyprland = { 
 #   enable = true;
 #   xwayland.enable = true;
 # };

  programs.waybar.enable = true;
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    kitty
    hyprpicker
    hyprpaper
    kdePackages.dolphin
    dunst
    kitty
    libnotify
    networkmanagerapplet
    rofi-wayland
    swww
    waybar
    thonny
    esptool
    luanti
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };
  
  fonts.packages = with pkgs; [
    font-awesome
    nerd-fonts.monoid
    nerd-fonts.victor-mono
    nerd-fonts.comic-shanns-mono
  ];
  

  xdg.portal.enable = true;
  xdg.portal.extraPortals = with pkgs; [
    xdg-desktop-portal-wlr
  ];
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };
  # networking.wireless.userControlled.enable = true;
  # networking.wireless.enable = true;
  # networking.wireless.networks = {
  #   UPC5171371 = {
  #     pskRaw = "f26c910be6981a041bb5c9fb849ec76c82e39db8338ef42123e0c64b677e65fc";
  #   };
  # };
  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  #system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?

  programs.ccache = {
    enable = true;
    packageNames = [ "linux_rpi4" ];
  };
  nix.sandboxPaths = [ (toString config.programs.ccache.cacheDir) ];  
  
  

  nixpkgs.overlays = [
  (self: super: {
    ccacheWrapper = super.ccacheWrapper.override {
      extraConfig = ''
        export CCACHE_DEBUG=1
        export CCACHE_COMPRESS=1
        export CCACHE_DIR="${config.programs.ccache.cacheDir}"
        export CCACHE_UMASK=007
        export CCACHE_SLOPPINESS=random_seed
        export KBUILD_BUILD_TIMESTAMP=""
        if [ ! -d "$CCACHE_DIR" ]; then
          echo "====="
          echo "Directory '$CCACHE_DIR' does not exist"
          echo "Please create it with:"
          echo "  sudo mkdir -m0770 '$CCACHE_DIR'"
          echo "  sudo chown root:nixbld '$CCACHE_DIR'"
          echo "====="
          exit 1
        fi
        if [ ! -w "$CCACHE_DIR" ]; then
          echo "====="
          echo "Directory '$CCACHE_DIR' is not accessible for user $(whoami)"
          echo "Please verify its access permissions"
          echo "====="
          exit 1
        fi
      '';
    };
  })
  (self: super: {
      linux = super.linux.overrideAttrs (oldAttrs: {
          depsBuildBuild = oldAttrs.depsBuildBuild // [ super.ccacheStdenv ];
      });
    })
];
  

  nix.settings.max-jobs = 1;
  nix.settings.cores = 1;
  nix.distributedBuilds = true;
  nix.settings.builders-use-substitutes = true;
  nix.buildMachines = [
    {
      hostName = "builder-local";
      #sshUser = "remotebuild";
      #sshKey = "/root/.ssh/remotebuild";
      systems = [ "x86_64-linux" "aarch64-linux" ];
      #system = pkgs.stdenv.hostPlatform.system;
      speedFactor = 100;
      protocol = "ssh-ng";
      supportedFeatures = [ "nixos-test" "big-parallel" "kvm" "benchmark" ];
    }
  ];

}
