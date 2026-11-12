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
      # woody has no inbound port for HTTP-01, so the vhost certs below are
      # DNS-01-issued with the same IONOS key harmonia already deploys here
      # (see harmonia.nix; the key lives in its service-scoped sops file).
      dns01 = inputs.self.lib.acmeDns01 config.sops.secrets."acme/ionos_api_key".path;
    in
    {
      imports = [
        # Inlined from ./_hardware-configuration.nix.
        (modulesPath + "/installer/scan/not-detected.nix")
        inputs.self.modules.nixos.system-default
        inputs.self.modules.nixos.donquezz
        inputs.self.modules.nixos.loghost
        inputs.self.modules.nixos.log-watchdog
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
        inputs.self.modules.nixos.acme
        inputs.chaotic.nixosModules.default
      ];

      # borg over reticulum: RNS-own bridge listener with its OWN identity
      # (not the root nix bridge), the borg user, identity allowlist replacing
      # per-repo ssh keys. pricklepants is the phase-1 client only.
      services.reticulum.rnshBorg = {
        enable = true;
        allowIdentities = [ constants.reticulum.identities.pricklepants.hash ];
      };

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

      # the machine-learning gunicorn control server insists on creating
      # ~/.gunicorn; with no usable home it dies every few minutes with
      # "[Errno 1] Operation not permitted: '/var/empty/.gunicorn'". point
      # HOME at a StateDirectory the immich user can write.
      services.immich.machine-learning.environment.HOME = "/var/lib/immich-ml";
      systemd.services.immich-machine-learning.serviceConfig.StateDirectory = "immich-ml";

      services.nginx.virtualHosts."immich.kauderwels.ch" = inputs.self.lib.proxyVhost {
        domain = "immich.kauderwels.ch";
        proxyPass = "http://127.0.0.1:${toString config.services.immich.port}";
        # All headers live here: a location with any proxy_set_header of its
        # own stops inheriting the server-level ones (nginx inheritance).
        extraConfig = ''
          client_max_body_size 5000M;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
      security.acme.certs."immich.kauderwels.ch" = dns01 { };

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

      fileSystems."/mnt/nas/immich" = inputs.self.lib.rcloneMount {
        device = "immich:immich";
        sftpPath = "/volume1/borgbackup/immich";
        configPath = "/etc/rclone-mnt.conf";
        uid = config.users.users.immich.uid;
        gid = config.users.users.immich.group;
        options = [
          #"_netdev"
          #"nofail"
          "vfs-write-back=1m" # write changes after one hour
          #"tpslimit=8"
          #"tpslimit-burst=16"
          #"bwlimit=1K"
          #"transfers=4"
          "log-file=/var/log/rclone.log"
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
          # Required for the reverse proxy vhost: https scheme + CSRF origins.
          PAPERLESS_URL = "https://paperless.kauderwels.ch";
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

      services.nginx.virtualHosts."paperless.kauderwels.ch" = inputs.self.lib.proxyVhost {
        domain = "paperless.kauderwels.ch";
        proxyPass = "http://127.0.0.1:${toString config.services.paperless.port}";
        extraConfig = ''
          client_max_body_size 100M;
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port "443";
        '';
      };
      security.acme.certs."paperless.kauderwels.ch" = dns01 { };

      networking.firewall.allowedTCPPorts = [
        config.services.immich.port
        config.services.paperless.port
        443 # TLS vhosts: immich/paperless behind nginx
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
      mesh.openInbound = lib.mkMerge [
        (lib.mkIf config.services.immich.enable [
          {
            port = config.services.immich.port;
            proto = "any";
          }
        ])
        (lib.mkIf config.services.paperless.enable [
          {
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

      fileSystems."/mnt/nas/paperless" = inputs.self.lib.rcloneMount {
        device = "paperless:paperless";
        sftpPath = "/volume1/borgbackup/paperless";
        configPath = "/etc/rclone-mnt.conf";
        uid = config.users.users.paperless.uid;
        gid = config.users.users.paperless.group;
        options = [
          #"_netdev"
          #"nofail"
          "vfs-write-back=1m" # write changes after one hour
          "tpslimit=16"
          "tpslimit-burst=32"
          "log-file=/var/log/rclone/paperless.log"
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
      # 24/7 homeserver: self-repair like the headless hosts. The      # graphical/interests-of-saved-work exclusion is relaxed here
      # because nobody sits at this display — it is reached via xrdp only.
      upgradeHealth.enable = true;

      # Bootloader.
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      boot.kernelPackages = pkgs.linuxPackages_cachyos-lto;
      services.scx.enable = true;

      networking.hostName = "woody"; # Define your hostname.

      # Enable networking
      networking.networkmanager.enable = true;

      # Enable network manager applet
      programs.nm-applet.enable = true;

      # Set your time zone.
      time.timeZone = "Europe/Berlin";

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
      };

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
        caja-with-extensions
        rclone
        #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
        #  wget
      ];
      services.yubikey-agent.enable = true;

      # Enable the OpenSSH daemon.
      services.openssh.enable = true;

      networking.firewall.logRefusedConnections = true;

      system.stateVersion = "24.11";

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
