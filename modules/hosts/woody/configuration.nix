# Host aspect (ADR 0014): the module list is assembled by lib.mkNixos
# (modules/nix/lib.nix) from flake.modules.nixos.woody; the flake-parts.nix
# one-liner next to this file declares the host into the flake.
# inputs/constants close over the head args. Two-file host: the hardware
# scan result is inlined below — no host-local glue.
{ inputs, lib, ... }:
let
  constants = import ../../../modules/global/_constants.nix;
in

{
  flake.modules.nixos.woody =
    {
      modulesPath,
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # Former ./_firefox.nix policy wordings.
      lock-false = {
        Value = false;
        Status = "locked";
      };
      lock-empty-string = {
        Value = "";
        Status = "locked";
      };
    in
    {
      imports = [
        # Inlined from ./_hardware-configuration.nix.
        (modulesPath + "/installer/scan/not-detected.nix")
        inputs.self.modules.nixos.system-default
        inputs.self.modules.nixos.donquezz
        inputs.self.modules.nixos.loghost
        inputs.self.modules.nixos.borg-server
        inputs.self.modules.nixos.kde
        inputs.self.modules.nixos.wifi
        inputs.self.modules.nixos.postgres-backup
        inputs.self.modules.nixos.harmonia
        inputs.self.modules.nixos.nfs-fee
        inputs.self.modules.nixos.nebula
        inputs.self.modules.nixos.prometheus
        inputs.self.modules.nixos.grafana
        inputs.self.modules.nixos.fritz-exporter
        inputs.chaotic.nixosModules.default
      ];

      # Inlined from ./_hardware-configuration.nix (zero host-local glue, ADR 0014).
      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
      ];
      boot.kernelModules = [ "kvm-intel" ];
      boot.kernelParams = [ "intel_pstate=passive" ];

      fileSystems."/" = {
        device = "/dev/disk/by-uuid/9bf7dc58-7c06-4f84-a028-84f59ae08bc8";
        fsType = "ext4";
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/D4AD-702D";
        fsType = "vfat";
        options = [
          "fmask=0077"
          "dmask=0077"
        ];
      };

      swapDevices = lib.mkForce [ ];

      # Enables DHCP on each ethernet and wireless interface.
      networking.useDHCP = lib.mkDefault true;
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

      boot.tmp.cleanOnBoot = true;
      # Former ./_immich.nix + ./_paperless.nix absorbed (retirement step 3B).
      # Shared firewall/inbound attrs merged; duplicate user defs folded.

      services.immich = {
        enable = true;
        host = "::";
        # secretsFile = config.vaultix.secrets.immich.path;
        database.createDB = true;
        machine-learning.enable = true;
        redis.enable = true;
        accelerationDevices = null;
        port = 2283;
        mediaLocation = "/mnt/nas/immich";
      };

      users.users.immich = {
        uid = 989;
        group = "immich";
        extraGroups = [
          "video"
          "render"
        ];
        #home = "/mnt/nas/immich";
        #createHome = true;
      };

      fileSystems."/mnt/nas/immich" = {
        device = "immich:immich";
        fsType = "rclone";
        options = [
          "nodev"
          #"_netdev"
          #"nofail"
          "noauto"
          "allow_other"
          "args2env"
          "x-systemd.automount"
          "cache_dir=/var/cache/rclone"
          "dir-cache-time=24h"
          "sftp-path-override=/volume1/borgbackup/immich"
          "vfs-cache-mode=full"
          "vfs-cache-min-free-space=10G"
          "vfs-fast-fingerprint"
          "config=/etc/rclone-mnt.conf"
          "vfs-write-back=1m" # write changes after one hour
          "vfs-cache-max-age=24h" # Retain cached files for up to 24 hours
          "vfs-read-chunk-size=32M" # Start with 32MB chunks for faster initial reads
          "vfs-read-chunk-size-limit=1G" # Allow chunk size to grow up to 1GB for large files
          "vfs-cache-poll-interval=30s"
          #"tpslimit=8"
          #"tpslimit-burst=16"
          #"bwlimit=1K"
          #"transfers=4"
          "log-level=INFO" # Log to stdout for debugging
          "log-file=/var/log/rclone.log"
          "x-systemd.requires=network-online.target"
          "x-systemd.after=network-online.target" # only after network came up
          "uid=${toString config.users.users.immich.uid}"
          "gid=${config.users.users.immich.group}"
        ];
      };

      systemd.services."immich-server.service".after = [ "mnt-nas-immich.mount" ];

      sops.secrets."paperless-admin-pass" = {
        sopsFile = ../../../secrets/services/paperless/secrets.yaml;
        owner = "paperless";
        group = "paperless";
        path = "/etc/paperless-admin-pass";
      };

      services.paperless = {
        enable = true;
        passwordFile = config.sops.secrets."paperless-admin-pass".path;
        configureTika = true;
        database.createLocally = true;
        dataDir = "/mnt/nas/paperless";
        port = 28981;
        address = "0.0.0.0";
        settings = {
          PAPERLESS_TASK_WORKERS = 1;
          PAPERLESS_THREADS_PER_WORKER = 2;
          PAPERLESS_OCR_LANGUAGE = "deu+eng";
          # PAPERLESS_APP_TITLE = "Paperless";
          # PAPERLESS_CONSUMER_IGNORE_PATTERN = [
          #   ".db"
          # ];
          # PAPERLESS_EMAIL_TASK_CRON = "0 */8 * * *";
          # https://github.com/paperless-ngx/paperless-ngx/issues/7383
          # PAPERLESS_OCR_USER_ARGS = {
          #   "invalidate_digital_signatures" = true;
          # };
        };
      };

      # Gotenberg 8.36 OTEL env silencing (paperless companion)
      systemd.services.gotenberg.environment = {
        OTEL_METRICS_EXPORTER = "none";
        OTEL_LOGS_EXPORTER = "none";
        OTEL_TRACES_EXPORTER = "none";
      };

      networking.firewall.allowedTCPPorts = [
        config.services.immich.port
        config.services.paperless.port
        # Former ./_home-assistant.nix:
        8123 # Home Assistant
        1883 # Mosquitto
      ];
      networking.firewall.interfaces."nebula.mesh".allowedTCPPorts = [
        config.services.immich.port
        config.services.paperless.port
      ]
      # Former ./_zabbix.nix:
      ++ [
        80
        443
        8080
        10051
      ];
      services.nebula.networks.mesh.firewall.inbound = lib.mkMerge [
        (lib.mkIf (config.services.immich.enable && config.services.nebula.networks.mesh.enable) [
          {
            cidr = constants.nebula.cidr;
            port = config.services.immich.port;
            proto = "any";
          }
        ])
        (lib.mkIf (config.services.paperless.enable && config.services.nebula.networks.mesh.enable) [
          {
            cidr = constants.nebula.cidr;
            port = config.services.paperless.port;
            proto = "any";
          }
        ])
      ];

      users.users.paperless = {
        uid = 315;
        group = "paperless";
        #home = "/mnt/nas/paperless";
        #createHome = true;
      };

      fileSystems."/mnt/nas/paperless" = {
        device = "paperless:paperless";
        fsType = "rclone";
        options = [
          "nodev"
          #"_netdev"
          #"nofail"
          "noauto"
          "allow_other"
          "args2env"
          "x-systemd.automount"
          "cache_dir=/var/cache/rclone"
          "dir-cache-time=24h"
          "sftp-path-override=/volume1/borgbackup/paperless"
          "vfs-cache-mode=full"
          "vfs-cache-min-free-space=10G"
          "vfs-fast-fingerprint"
          "vfs-write-back=1m" # write changes after one hour
          "vfs-cache-max-age=24h" # Retain cached files for up to 24 hours
          "vfs-read-chunk-size=32M"
          "vfs-read-chunk-size-limit=1G"
          "vfs-cache-poll-interval=30s"
          "tpslimit=16"
          "tpslimit-burst=32"
          "log-level=INFO"
          "log-file=/var/log/rclone/paperless.log"
          "config=/etc/rclone-mnt.conf"
          "x-systemd.requires=network-online.target"
          "x-systemd.after=network-online.target"
          "uid=${toString config.users.users.paperless.uid}"
          "gid=${config.users.users.paperless.group}"
        ];
      };
      # The ./_*.nix host-local glue (xrdp nas nofile firefox power zabbix
      # home-assistant) absorbed here and in the firewall folds above.
      services.xrdp.enable = true;
      #services.xrdp.defaultWindowManager = "mate-session";
      services.xrdp.defaultWindowManager = "startplasma-x11";
      services.xrdp.openFirewall = true;
      # xrdp logs every RDP callback at INFO; that produced ~1GB/week of
      # pointer addresses on the loghost.  WARNING is enough to troubleshoot.
      services.xrdp.extraConfDirCommands = ''
        substituteInPlace $out/sesman.ini --replace-fail 'LogLevel=INFO' 'LogLevel=WARNING'
        substituteInPlace $out/xrdp.ini --replace-fail 'LogLevel=INFO' 'LogLevel=WARNING'
      '';

      # Former ./_nas.nix.
      # For mount.cifs, required unless domain name resolution is not needed.
      # environment.systemPackages = [ pkgs.cifs-utils ];
      fileSystems."/mnt/share" = {
        device = "//bergmannnas/home";
        fsType = "cifs";
        options =
          let
            # this line prevents hanging on network split
            automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";

          in
          [
            "${automount_opts},credentials=/etc/nixos/smb-secrets,uid=${toString config.users.users.jeromeb.uid},gid=${toString config.users.groups.users.gid}"
          ];
      };
      services.gvfs.enable = true;

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

      # Former ./_nofile.nix.
      systemd.settings.Manager = {
        DefaultLimitNOFILE = lib.mkForce "65536:1048576";
      };
      security.pam.loginLimits = [
        {
          domain = "*";
          type = "soft";
          item = "nofile";
          value = "65536";
        }
        {
          domain = "*";
          type = "hard";
          item = "nofile";
          value = "1048576";
        }
      ];

      # Former ./_firefox.nix.
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
            "Exceptions" = [ ];
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
            Block = [ "https://9gag.com/" ];
            Exceptions = [ ];
          };
        };
      };

      # Former ./_power.nix.
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
      # services.ollama = {
      #   enable = true;
      #   acceleration = false;
      #   environmentVariables = {
      #     OLLAMA_CONTEXT_LENGTH="32768";
      #   };
      # };

      # Former ./_zabbix.nix.
      #services.zabbixServer ={
      #  enable = true;
      #  package = pkgs.zabbix74.server;
      #};

      services.zabbixWeb = {
        enable = true;
        #    server.port = 8080;
        frontend = "nginx";
        package = pkgs.zabbix74.web;
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
        package = pkgs.zabbix74.agent;
        #    settings = {
        #      Plugins.MQTT.Session.iot = {
        #        User = "root";
        #        Password = "<redacted, see sops mosquitto-password>";
        #        Topic = "#";
        #      };
        #    };
      };

      # Former ./_home-assistant.nix.
      sops.secrets."mosquitto-password" = {
        sopsFile = ../../../secrets/hosts/woody/services.yaml;
      };

      services.home-assistant = {
        enable = false; # doesn't build!?
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
          default_config = { };
          mqtt = {
            climate = [
              {
                name = "Emelies Heizung";
                modes = [
                  "off"
                  "heat"
                  "auto"
                ];
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
              passwordFile = config.sops.secrets."mosquitto-password".path;
              #settings.allow_anonymous = true;
            };
          }
          #      {
          #        users.DVES_USER = {
          #          acl = [
          #            "readwrite #"
          #          ];
          #          #omitPasswordAuth = true;
          #          passwordFile = config.sops.secrets."mosquitto-password".path;      #          #settings.allow_anonymous = true;
          #        };
          #      }
        ];
      };
      zramSwap.enable = true;

      # 24/7 homeserver: self-repair like the headless hosts. The
      # graphical/interests-of-saved-work exclusion is relaxed here
      # because nobody sits at this display — it is reached via xrdp only.
      upgradeHealth.enable = true;

      # Bootloader.
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      boot.kernelPackages = pkgs.linuxPackages_cachyos-lto;
      services.scx.enable = true;

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
      nix.settings.max-jobs = 6;
      nix.settings.cores = 6;
      nix.distributedBuilds = lib.mkForce false;
      nix.settings.trusted-users = [ "jeromeb" ];

      users.groups.plugdev = { };
      # Define a user account. Don't forget to set a password with ‘passwd’.
      users.users.jeromeb = {
        isNormalUser = true;
        description = "Jerome Bergmann";
        extraGroups = [
          "networkmanager"
          "wheel"
          "plugdev"
        ];
        packages = with pkgs; [
          #goose-cli
          htop
          rbw
          pinentry-curses
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
      environment.sessionVariables = {
        SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/rbw/ssh-agent-socket";
      };
      # Allow unfree packages
      nixpkgs.config.allowUnfree = true;

      # List packages installed in system profile. To search, run:
      # $ nix search wget
      environment.systemPackages = with pkgs; [
        immich-machine-learning
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
        #elmPackages.elm-analyse
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
        #enable = true;
        # allowReboot  = true;
        dates = "hourly";
      };
      #useComin = true;

      nix.gc = {
        automatic = true;
        dates = "hourly";
        options = "--delete-older-than 7d";
      };

      # Please do upgrades in Background
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

      # A glibc bump changes the collation version, and postgres then warns on
      # every connection. Reindex each connectable database once, then record the
      # new version. Best-effort: never keep postgres from starting.
      systemd.services.postgresql.postStart = lib.mkAfter ''
        psql=${config.services.postgresql.package}/bin/psql
        "$psql" -tAc "select datname from pg_database where datallowconn and datcollversion is not null and datcollversion <> '${pkgs.glibc.version}'" |
          while IFS= read -r db; do
            [ -n "$db" ] || continue
            if "$psql" -d "$db" -c "REINDEX DATABASE \"$db\";"; then
              "$psql" -d postgres -c "ALTER DATABASE \"$db\" REFRESH COLLATION VERSION;" || true
            fi
          done
        true
      '';

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
    };
}
