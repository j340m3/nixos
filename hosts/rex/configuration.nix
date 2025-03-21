# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

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

  in 
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      #./mate.nix
      ./hardened.nix
      ../common.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  boot.kernelPackages = pkgs.linuxPackages_zen;

  swapDevices = [ { device = "/swapfile"; size = 2048; } ];
  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;

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
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  #services.xserver.displayManager.gdm.enable = true;
  #services.xserver.displayManager.gdm.wayland = true;
  #services.xserver.desktopManager.gnome.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.mate.enable = true;
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

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.jeromeb = {
    isNormalUser = true;
    description = "Jerome";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.zsh;
    packages = with pkgs; [
       gparted
       nmap
       webex
       signal-desktop
       (makeAutostartItem { name = "signal-desktop"; package = signal-desktop; })
       telegram-desktop
       (makeAutostartItem { name = "telegram.desktop"; package = telegram-desktop; srcPrefix = "org.";})
       telegram-desktop
       #jetbrains.pycharm-professional
       elmPackages.elm
       python3Full
       vulnix
       git
       zip
       lynis
       zabbix.agent
       spotify
       #nur.repos.rycee.firefox-addons.bitwarden
       (vscode-with-extensions.override {
         # When the extension is already available in the default extensions set.
         vscodeExtensions = with vscode-extensions; [
           jnoortheen.nix-ide
           
         ];
       })
       (makeAutostartItem { name = "firefox"; package = firefox; })
       (makeAutostartItem { name = "spotify"; package = spotify; })
       mosh
    #  thunderbird
       libreoffice-qt
       hunspell
       hunspellDicts.de_DE
       hunspellDicts.en_US
       remmina
       traceroute
       statix
       alejandra
    ];
  };

  # Install firefox.
  
  programs.firefox = {
    enable = true;
    package = pkgs.firefox-esr;
    policies = {
      Cookies = {
        "Locked" = true;
        "Behavior" = "reject-tracker";
        "BehaviorPrivateBrowsing" = "reject-tracker";
        "DisableFirefoxAccounts" = true;
      };

      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DontCheckDefaultBrowser = true;
      DisablePocket = true;
      EnableTrackingProtection = {
          "Value" = true;
          "Locked" = true;
          "Cryptomining" = true;
          "Fingerprinting" = true;
          "Exceptions" = [];
      };

      OfferToSaveLogins = false;
      PasswordManagerEnabled = false;
      SanitizeOnShutdown = {
        "Cache" = true;
        "Cookies" = true;
        "Downloads" = false;
        "FormData" = true;
        "History" = false;
        "Sessions" = true;
        "SiteSettings" = true;
        "OfflineApps" = true;
        "Locked" = true;
      };

      SearchBar = "unified";

      Preferences = {
        # Privacy settings
        "extensions.pocket.enabled" = lock-false;
        "browser.newtabpage.pinned" = lock-empty-string;
        "browser.topsites.contile.enabled" = lock-false;
        "browser.newtabpage.activity-stream.showSponsored" = lock-false;
        "browser.newtabpage.activity-stream.system.showSponsored" = lock-false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = lock-false;

        # "browser.startup.homepage" = "https://duckduckgo.com";
        "browser.search.defaultenginename" = "DuckDuckGo";
        "browser.search.order.1" = "DuckDuckGo";

        "signon.rememberSignons" = false;
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        "browser.aboutConfig.showWarning" = false;
        "browser.compactmode.show" = true;
        "browser.cache.disk.enable" = false; # Be kind to hard drive

        # Firefox 75+ remembers the last workspace it was opened on as part of its session management.
        # This is annoying, because I can have a blank workspace, click Firefox from the launcher, and
        # then have Firefox open on some other workspace.
        "widget.disable-workspace-management" = true;
      };

      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
        };
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
          installation_mode = "force_installed";
        };
        "jid1-MnnxcxisBPnSXQ@jetpack" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/privacy-badger17/latest.xpi";
          installation_mode = "force_installed";
        };
        "extension@tabliss.io" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/tabliss/latest.xpi";
          installation_mode = "force_installed";
        };
        "gdpr@cavi.au.dk" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/consent-o-matic/latest.xpi";
          installation_mode = "force_installed";
        };
      };

      SearchEngines = {
        Default = "DuckDuckGo";
      };

      WebsiteFilter = {
        Block = ["https://9gag.com/"];
        Exceptions = [];
      };
    };
  };
  
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
    powerline
    powerline-fonts
    powerline-symbols
    nebula
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

  system.autoUpgrade.enable = true;

  nix.settings.auto-optimise-store = true;

  services.ollama = {
    enable = true;
    acceleration = false;
  };
  
  programs.thefuck.enable = true;
  
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    ohMyZsh = {
      enable = true;
      plugins = [ "git" "thefuck" "sudo" ];
      theme = "frisk";
    };
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

  services.zabbixAgent = {
    enable = true;
    openFirewall = true;
    server = "10.0.0.0/24";
    settings = {
      Hostname = "rex";
    };
  };

  services.nebula.networks.mesh = {
    enable = true;
    isLighthouse = false;
    lighthouses = [ "10.0.0.1" ];
    settings = {
        cipher= "aes";
        punchy.punch=true;
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
  };
  networking.nameservers = [ "10.0.0.1" "1.1.1.1" "8.8.8.8" "9.9.9.9" ];
  networking.useDHCP = lib.mkForce true;
}
