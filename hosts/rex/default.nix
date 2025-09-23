# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, home-manager, ... }:

let
    lock-false = {
      Value = false;
      Status = "locked";
    };
    lock-true = {
      Value = true;
      Status = "locked";
    };
    lock-empty-string = {
      Value = "";
      Status = "locked";
    };
    dontCheckPython = drv: drv.overridePythonAttrs (old: { doCheck = false; });
  in 
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../desktop-environments/mate.nix
      #./hardened.nix
      ../../modules/common 
      ../../modules/logging.nix
      ../../modules/nebula.nix
      ../../modules/zabbix.nix
      #../../modules/peerix.nix
      ../../modules/cool-shell.nix
      ../../modules/google-drive.nix
      home-manager.nixosModules.home-manager
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # boot.kernelPackages = pkgs.linuxPackages_zen;
  boot.extraModulePackages = with config.boot.kernelPackages; [ virtualboxGuestAdditions ];
  systemd.services."virtualboxClientDragAndDrop" = {
    wantedBy = lib.mkForce [ ]; #Disable Drag and Drop
    #execStart=lib.mkForce [""];
  };
  #boot.kernelPackages = pkgs.linuxPackages_cachyos;

  #swapDevices = [ { device = "/swapfile"; size = 2048; } ];
  #services.swapspace.enable = true;
  #services.swapspace.settings = {
  #  lower_freelimit=50;
  #  upper_freelimit=70;
  #  freetarget=60;
  #  buffer_elasticity=100;
  #  cache_elasticity=100;
  #};
  #boot.kernel.sysctl = { "vm.swappiness" = 1;};

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  virtualisation.diskSize = "auto";
  #virtualisation.additionalSpace = "5G";
  boot.growPartition = true;

  networking.hostName = "rex"; # Define your hostname.
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
  #services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  #services.xserver.displayManager.gdm.enable = true;
  #services.xserver.displayManager.gdm.wayland = true;
  #services.xserver.desktopManager.gnome.enable = true;
  #services.xserver.displayManager.lightdm.enable = true;
  #services.xserver.desktopManager.mate.enable = true;
  #services.xserver.desktopManager.mate.enableWaylandSession = true;

  #services.xserver.desktopManager.mate.extraPanelApplets = [];
  
  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "de";

  # Enable CUPS to print documents.
  #services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  #hardware.pulseaudio.enable = false;
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

  allowReboot = false;
  #useComin = true;
  virtualisation.docker.enable = true;
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.jeromeb = {
    isNormalUser = true;
    description = "Jerome";
    extraGroups = [ "networkmanager" "wheel" "docker"];
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;
  services.yubikey-agent.enable = true;
  services.udev.packages = [ pkgs.libfido2 ];
  # Install firefox.
  home-manager.backupFileExtension = "hmbackup";
  home-manager.users.jeromeb = import ../../home;
/*   home-manager.users.jeromeb = {pkgs, ...} : {
    nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      # Add additional package names here
      "spotify"
    ];
    home.packages = with pkgs; [
      btop
      #acct
      nix-index
       #anytype
       #gparted
       nmap
       #webex
       signal-desktop
       (makeAutostartItem { name = "signal"; package = signal-desktop; prependExtraArgs = [ "--start-in-tray" ];})
       telegram-desktop
       (makeAutostartItem { name = "telegram.desktop"; package = telegram-desktop; srcPrefix = "org.";})
       #jetbrains.pycharm-professional
       elmPackages.elm
       /* python3Full
       (python311.withPackages(ps: with ps; [ 
          #(dontCheckPython numpy)
          pytest
          (dontCheckPython matplotlib)
        ])) 
       vulnix
       git
       zip
       lynis
       
       #spotify
       #nur.repos.rycee.firefox-addons.bitwarden
       /* (vscode-with-extensions.override {
         # When the extension is already available in the default extensions set.
         vscodeExtensions = with vscode-extensions; [
           jnoortheen.nix-ide
           bbenoist.nix
           elmtooling.elm-ls-vscode
           # ms-python.python #TODO: FIXME Doesn't work currently
           charliermarsh.ruff
         ];
         vscode = vscodium;
       }) 
       #(makeAutostartItem { name = "firefox"; package = firefox; })
       #(makeAutostartItem { name = "spotify"; package = spotify; })
       #mosh
      #thunderbird
       #libreoffice
       #hunspell
       #hunspellDicts.de_DE
       #hunspellDicts.en_US
       remmina
       traceroute
       statix
       alejandra
       age
       wezterm
    ];
    home = {
      username = "jeromeb";
      homeDirectory = "/home/jeromeb";
    };
    home.stateVersion = "25.05";
    programs.home-manager.enable = true;
    programs.pay-respects.enable = true;
  
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      #autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
      /* ohMyZsh = {
        enable = true;
        plugins = [ "git" "sudo" ];
        theme = "frisk";
      }; 
    };
  }; */
  
  
  # Allow unfree packages
  #nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
    #powerline #TODO: Powerline is broken currently
    powerline-fonts
    powerline-symbols
    nebula
    exfat
    zabbix.agent
    #exfatprogs

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
  # services.openssh.enable = true;

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
  system.stateVersion = "24.11"; # Did you read the comment?

  nix.settings.auto-optimise-store = true;

  services.ollama = {
    enable = true;
    acceleration = false;
  };
  
  

  #nixpkgs.config.packageOverrides = pkgs: {
  #  nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") {
  #    inherit pkgs;
  #  };
  #};
  /* services.zabbixServer.enable = true;
  services.zabbixWeb = {
    enable = true;
    virtualHost = {
      hostName = "zabbix.localhost";
      adminAddr = "webmaster@localhost";
    };
  };
  
  services.zabbixAgent = {
    enable = true;
    server = "localhost";
  }; */

  /* services.zabbixAgent = {
    enable = true;
    openFirewall = true;
    server = "10.0.0.0/24";
    settings = {
      Hostname = "rex";
    };
  }; */

  /* services.nebula.networks.mesh = {
    enable = true;
    isLighthouse = false;
    lighthouses = [ "10.0.0.1" ];
    relays = [ "10.0.0.1" ];
    settings = {
      cipher = "aes";
      punchy.punch=true;
      dns = {
        host = "10.0.0.1";
        port = 53;
      };
    };
    cert = "/etc/nebula/rex.crt";
    key = "/etc/nebula/rex.key";
    ca = "/etc/nebula/ca.crt";
    staticHostMap = {
        "10.0.0.1" = [
                "194.164.125.154:4242"
                ];
        };
    firewall.outbound = [
  {
    cidr = constants.nebula.cidr;
    port = "any";
    proto = "any";
  }
];
    firewall.inbound = [
  {
    cidr = constants.nebula.cidr;
    port = "any";
    proto = "any";
  }
];
  }; */
  networking.nameservers = [ "10.0.0.1" "1.1.1.1" "8.8.8.8" "9.9.9.9" ];
  networking.useDHCP = lib.mkForce true;
}
