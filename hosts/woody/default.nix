# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, home-manager,... }:

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
      ../../modules/common 
      ../../users/donquezz.nix
      ../../modules/loghost.nix
      ../../modules/borg-server.nix
      ../../modules/remote-builder.nix
      #../../modules/peerix.nix
      ../../modules/reticulum.nix
      ../../desktop-environments/kde.nix
      ../../desktop-environments/mate.nix
      ../../modules/wifi.nix
      ../../modules/immich.nix
      ../../modules/paperless.nix
      ../../modules/harmonia.nix
      ../../modules/nfs-fee.nix
      
      # ./firefox.nix
      #(fetchTarball "https://github.com/nix-community/nixos-vscode-server/tarball/master")
      #<home-manager/nixos>
    ];
  
  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "woody"; # Define your hostname.
  #networking.domain = "fritz.box";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable network manager applet
  programs.nm-applet.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

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

  # Enable the MATE Desktop Environment.
  #services.xserver.displayManager.lightdm.enable = true;
  #services.xserver.desktopManager.mate.enable = true;

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
    # media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;
  
  users.groups.plugdev = {};
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.jeromeb = {
    isNormalUser = true;
    description = "Jerome Bergmann";
    extraGroups = [ "networkmanager" "wheel" "plugdev" ];
    packages = with pkgs; [
      goose-cli
      htop
      # home-manager
      github-desktop
      (vscode-with-extensions.override {
        vscode = vscodium;
        vscodeExtensions = with vscode-extensions; [
          bbenoist.nix
        ];
      })
    #  thunderbird
    ];
  };
  #users.users.eve.isNormalUser = true;
  /* home-manager.users.jeromeb = { pkgs, ... }: {
    home.packages = [ pkgs.atool pkgs.httpie ];
    programs.bash.enable = true;

    # The state version is required and should stay at the version you
    # originally installed.
    home.stateVersion = "24.11";
    programs.home-manager.enable = true;
    programs.neovim.plugins = [ pkgs.vimPlugins.parinfer-rust ];

  };
  home-manager.backupFileExtension = "backup.hm"; */

  # Install firefox.
  # programs.firefox.enable = true;
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
    intel-undervolt
    undervolt
    s-tui
    stress
    btop
    novnc
    cifs-utils
    libfido2
    pam_u2f
    vulnix
    git
    elmPackages.elm
    elmPackages.elm-analyse
    #elmPackages.elm-coverage
    elmPackages.elm-format
    elmPackages.elm-json
    elmPackages.elm-review
    elmPackages.elm-upgrade
    mate.caja-with-extensions
    rclone
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
  ];
  services.yubikey-agent.enable = true;
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

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  networking.firewall.logRefusedConnections = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

  system.autoUpgrade = {
    enable = true;
   # allowReboot  = true;
    dates = "hourly";
  };

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 30d";
  };

  # Please do upgrades in Background
  /* nix = {
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
    settings.auto-optimise-store = true;
    settings.max-jobs = 1;
    settings.cores = 1;
    daemonIOSchedClass = lib.mkDefault "idle";
    daemonCPUSchedPolicy = lib.mkDefault "idle";
  };
  systemd.services.nix-daemon.serviceConfig.Slice = "-.slice";
  # always use the daemon, even executed  with root
  environment.variables.NIX_REMOTE = "daemon";
  systemd.services.nix-daemon.serviceConfig = {
    MemoryHigh = "800M";
    MemoryMax = "1G";
  }; */

  services.xrdp.enable = true;
  #services.xrdp.defaultWindowManager = "mate-session";
  services.xrdp.defaultWindowManager = "startplasma-x11";
  services.xrdp.openFirewall = true;
  #services.xrdp.extraConfDirCommands = "substituteInPlace $out/sesman.ini --replace-fail '#SessionSockdirGroup=xrdp' 'SessionSockdirGroup=xrdp'";

  
  services.home-assistant = {
    enable = true;
    extraComponents = [
      # Components required to complete the onboarding
      "esphome"
      "met"
      "radio_browser"
      "tasmota"
      "google_translate"
      "prusalink"
      "cast"
      "spotify"
    ];
    config = {
      # Includes dependencies for a basic setup
      # https://www.home-assistant.io/integrations/default_config/
      default_config = {};
      mqtt = {
        climate = [
          {
            name = "Emelies Heizung";
            modes = ["off" "heat" "auto"];
            min_temp = 5;
            max_temp = 26;
            temp_step = 0.5;
            precision = 0.1;
            mode_command_topic = "cmnd/tasmota_D84500/EQ3/001A221B9574/mode";
            temperature_command_topic = "cmnd/tasmota_D84500/EQ3/001A221B9574/settemp";
            temperature_state_topic = "stat/EQ3/001A221B9574";
            temperature_state_template = "{{ value_json.temp }}";
            mode_state_topic = "stat/EQ3/001A221B9574";
            mode_state_template = "{{ value_json.hassmode }}";
            #current_temperature_topic = "tele/tasmota_D84500/SENSOR";
            # current_temperature_template: '{{ value_json["AM2301"].Temperature - 4.2 }}'
            #current_temperature_template = "{{ value_json[\"AM2301\"].Temperature }}";
            #current_humidity_topic = "tele/tasmota_D84500/SENSOR";
            #current_humidity_template = "{{ value_json[\"AM2301\"].Humidity }}";
          }
        ];
        sensor = [
          {
            name = "Palme_Boden";
            state_topic = "Palme/soil";
            unique_id = "mqtt_palme_soil";
            device_class = "moisture";
          }
        ];
      };
    };
  };
  networking.firewall.allowedTCPPorts = [ 
    8123 # Home Assistant
    1883 # Mosquitto
  ];

  services.mosquitto = {
    enable = true;
    # port = 1883;
    listeners = [
      {
        users.root = {
          acl = [ 
            "readwrite #"
            #"topic write tasmota/discovery/#" 
          ];
          #omitPasswordAuth = true;
          password = "root123";
          #settings.allow_anonymous = true;
        };
      }
#      {
#        users.DVES_USER = {
#          acl = [
#            "readwrite #"
#          ];
#          #omitPasswordAuth = true;
#          password = "root123";
#          #settings.allow_anonymous = true;
#        };
#      }
    ];
  };

  
  # For mount.cifs, required unless domain name resolution is not needed.
  # environment.systemPackages = [ pkgs.cifs-utils ];
  fileSystems."/mnt/share" = {
    device = "//bergmannnas/home";
    fsType = "cifs";
    options = let
      # this line prevents hanging on network split
      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";

    in ["${automount_opts},credentials=/etc/nixos/smb-secrets,uid=${toString config.users.users.jeromeb.uid},gid=${toString config.users.groups.users.gid}"];
  };
  services.gvfs.enable = true;

  
#  systemd.services.monitoring = {
#    path = with pkgs; [
#      bc
#      ipcalc
#      curl
#      procps
#      gawk
#      coreutils
#      iproute2
#    ];
#    script = ''
#      ${pkgs.bash}/bin/bash /root/system-monitoring.sh --NAME "NixOS-GB" --LA1 --LA5 --LA15 --CPU 80 --RAM 80 --DISK 80 --SSH-LOGIN --SFTP-MONITOR --REBOOT 2>&1 >> /var/log/monitoring/monitoring.log
#    '';
#    wantedBy = [ "multi-user.target" ];
#  };

  services.nebula.networks.mesh = {
    listen.host = "[::]";
    enable = true;
    isLighthouse = false;
    lighthouses = [ "10.0.0.1" "10.0.0.5"];
    relays = [ "10.0.0.1" "10.0.0.5"];
    settings = {
        cipher= "aes";
        punchy.punch=true;
        punchy.respond=true;
        };
    cert = "/etc/nebula/woody.crt";
    key = "/etc/nebula/woody.key";
    ca = "/etc/nebula/ca.crt";
    staticHostMap = {
        "10.0.0.1" = [
                "194.164.125.154:4242"
                ];
        "10.0.0.5" = [ "194.164.54.40:4242" ];
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

  networking.firewall.interfaces."nebula.mesh".allowedTCPPorts = [ 80 443 8080 10051];
  services.zabbixServer ={
    enable = true;
    package = pkgs.zabbix72.server;
  };

  services.zabbixWeb = {
    enable = true;
#    server.port = 8080;
    frontend = "nginx";
    package = pkgs.zabbix72.web;
    nginx.virtualHost = {
      #hostName = "woody";
      #adminAddr = "webmaster@localhost";
      listen = [
          {
            addr = "0.0.0.0";
            port = 80;
            ssl = false;
          }
        ];
    };
  };
  
  services.zabbixAgent = {
    enable = true;
    server = "localhost";
    package = pkgs.zabbix72.agent;
#    settings = {
#      Plugins.MQTT.Session.iot = {
#        User = "root";
#        Password = "root123";
#        Topic = "#";
#      };
#    };
  };
  
  #services.vscode-server.enable = true;
  services.udev.packages = [ pkgs.libfido2 ];
  #services.udev.packages = [ pkgs.yubikey-personalization ];
  
  #services.udev.extraRules = ''
  #  # this udev file should be used with udev 188 and newer
  #  ACTION!="add|change", GOTO="u2f_end"
  #
  #  # PID for FIDO U2F
  #  KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="096e", ATTRS{idProduct}=="0854", TAG+="uaccess"
  #
  #  LABEL="u2f_end"
  #'';

  
#  programs.gnupg.agent = {
#    enable = true;
#    enableSSHSupport = true;
#  };

  # This is on by default, making auto-cpufreq unable to work
  services.power-profiles-daemon.enable = false;
  
  powerManagement.enable = true;
  powerManagement.cpuFreqGovernor = "powersave";
  powerManagement.powertop.enable = true;   
  services.thermald.enable = true;
  services.auto-cpufreq.enable = true;
  services.auto-cpufreq.settings = {
    battery = {
      governor = "schedutil";
      turbo = "never";
    };
    charger = {
      governor = "schedutil";
      turbo = "auto";
      energy_performance_preference = "balance_power";
      energy_perf_bias = "balance_power";
  };

  

}; 
  services.ollama = {
    enable = true;
    acceleration = false;
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH="32768";
    };
  };


environment.etc."rclone-mnt.conf" = {
  text = ''
    [immich]
    type = sftp
    host = bergmannnas.fritz.box
    user = borg
    key_file = /root/.ssh/id_rsa

    [rsyslog]
    type = sftp
    host = bergmannnas.fritz.box
    user = borg
    key_file = /root/.ssh/id_rsa

    [paperless]
    type = sftp
    host = bergmannnas.fritz.box
    user = borg
    key_file = /root/.ssh/id_rsa
  '';
  mode = "755";
};
}
