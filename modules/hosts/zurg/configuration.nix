# Host aspect: the module list for this host is assembled by lib.mkNixos
# (modules/nix/lib.nix) from flake.modules.nixos.zurg; the flake-parts.nix
# one-liner next to this file declares the host into the flake.
{ inputs, ... }:

{
  flake.modules.nixos.zurg =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      imports = [
        # Include the results of the hardware scan.
        ./_hardware-configuration.nix
        # Wired here (the repo flake does not add these globally, unlike the
        # standalone /etc/nixos flake).
        inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p51
        inputs.stylix.nixosModules.stylix
        inputs.self.modules.nixos.agent-md
      ];

      # Use the systemd-boot EFI boot loader.
      #boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      #boot.loader.efi.efiSysMountPoint = "/boot1";
      networking.hostName = "zurg"; # Define your hostname.
      # Pick only one of the below networking options.
      #networking.wireless.enable = false;  # Enables wireless support via wpa_supplicant.
      networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

      boot.loader.grub = {
        enable = true;
        efiSupport = true;
        configurationLimit = 5;
        mirroredBoots = [
          {
            devices = [ "nodev" ];
            path = "/boot-fallback";
          }
          {
            devices = [ "nodev" ];
            path = "/boot";
          }

        ];
      };

      boot.swraid.enable = true;
      boot.swraid.mdadmConf = ''
        HOMEHOST zurg
      '';

      # Set your time zone.
      time.timeZone = "Europe/Berlin";

      # Configure network proxy if necessary
      # networking.proxy.default = "http://user:password@proxy:port/";
      # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

      # Select internationalisation properties.
      i18n.defaultLocale = "de_DE.UTF-8";
      console = {
        font = "Lat2-Terminus16";
        #  keyMap = "de";
        useXkbConfig = true; # use xkb.options in tty.
      };

      # Enable the X11 windowing system.
      services.xserver.enable = true;

      # Enable the GNOME Desktop Environment.
      services.xserver.displayManager.gdm.enable = true;
      services.xserver.desktopManager.gnome.enable = true;

      # Configure keymap in X11
      services.xserver.xkb.layout = "de";
      # services.xserver.xkb.options = "eurosign:e,caps:escape";

      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      # GNOME 50 clipboard regression is in GTK's content-type matching, not
      # fixable from here. Use kitty (terminal.nix) as the default instead.
      environment.variables.TERMINAL = "kitty";
      programs.dconf.profiles.user.databases = [
        {
          settings."org/gnome/desktop/default-applications/terminal" = {
            exec = "kitty";
            "exec-arg" = "";
          };
        }
      ];
      # Enable CUPS to print documents.
      # services.printing.enable = true;

      # Enable sound.
      # services.pulseaudio.enable = true;
      # OR
      # services.pipewire = {
      #   enable = true;
      #   pulse.enable = true;
      # };

      # Enable touchpad support (enabled default in most desktopManager).
      # services.libinput.enable = true;
      users.mutableUsers = false;
      users.users.jeromeb = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "networkmanager"
          "vboxusers"
        ];
        hashedPassword = "$6$uT1lJkmEB26nRxwe$30NmQk6/m9P8HvK/xglPmmXyoY3HKqxoTONUpRUXX51ja2XiWGKHqKnSPWKlkF/mMWTPFHj/h0/WzxyXNAfTd/";
        packages = with pkgs; [
          pinentry-all
          undervolt
          btop
          signal-desktop
          telegram-desktop
          spotify
          #librewolf
          seclists
          wireguard-tools
          ffuf
          gobuster
          dig
          nmap
          whois
          trufflehog
          git
          pciutils
          wget
          obsidian
          lshw
          tcpdump
          luanti
          traceroute
          libreoffice
          #bitwarden-desktop
          nh
          zed-editor
          firefox
          rbw
          #vmware-workstation
        ];
      };
      programs.flashprog.enable = true;

      # Former ./_terminal.nix (retirement step 3C); its systemPackages items
      # merged into the list below, as are the ./_fingerprint/_gaming/_llm
      # systemPackages (all ./_*.nix host-local glue absorbed).
      stylix.enable = true;
      stylix.base16Scheme = "${inputs.tinted-schemes}/base16/flexoki-light.yaml";
      environment.systemPackages = with pkgs; [
        (wordlists.override {
          lists = [
            rockyou
            seclists
          ];
        })
        efibootmgr
        kitty
        gnomeExtensions.activate-linux
        # Former ./_fingerprint.nix:
        fprintd
        # Former ./_gaming.nix:
        mangohud
        protonup-qt
        lutris
        bottles
        heroic
        # Former ./_llm.nix:
        inputs.opencode-dev.packages.${pkgs.system}.default
        opencode
        opencode-desktop
      ];

      environment.sessionVariables = {
        SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/rbw/ssh-agent-socket";
      };

      # The ./_*.nix host-local glue (gaming fingerprint fonts de llm update)
      # absorbed here and in the systemPackages list above.
      # Former ./_gaming.nix.
      hardware.graphics.enable = true;
      hardware.graphics.enable32Bit = true;
      services.xserver.videoDrivers = [
        "nvidia"
      ];
      hardware.nvidia.modesetting.enable = true;
      hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
      #hardware.nvidia.open = true;
      #nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
      #           "nvidia-x11"
      #           "nvidia-settings"
      #         ];
      nixpkgs.config.allowUnfree = true;
      hardware.enableRedistributableFirmware = true;
      programs.steam = {
        enable = true;
      };
      nix.daemonCPUSchedPolicy = "idle";
      nix.daemonIOSchedClass = "idle";
      #environment.systemPackages = [ (pkgs.writeShellScriptBin "reboot-kexec" (builtins.readFile ./reboot-kexec.sh)) ];
      programs.steam.gamescopeSession.enable = true;
      programs.gamemode.enable = true;

      # Former ./_fingerprint.nix.
      services.fprintd.enable = true;

      # Former ./_fonts.nix.
      fonts.packages = with pkgs; [
        nerd-fonts.victor-mono
      ];

      # Former ./_de.nix.
      programs.hyprland.enable = true;

      # Former ./_llm.nix.
      nix.settings = {
        substituters = [
          "https://cache.nixos-cuda.org"
          "https://cache.chaotic.cx"
        ];
        trusted-public-keys = [
          "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
          "chaotic.cachix.org-1:Zf7C6GVRqJjU8B/ihd+psPVKp3/7Or/FSvOP3/9aB8Y="
        ];
      };
      services.ollama = {
        enable = true;
        package = pkgs.ollama-cuda.override {
          cudaArches = [ "52" ]; # Quadro M1200/M2200 (Maxwell) im ThinkPad P51
          cudaPackages = pkgs.cudaPackages_12; # CUDA 13 dropped Maxwell (sm_52)
        };
        environmentVariables = {
          # 1. Zwingt den Kontext auf ein kleineres Fenster (Standard ist oft 4K/8K oder mehr)
          # OLLAMA_CONTEXT_LENGTH = "2048";

          # 2. Komprimiert den Schlüssel-Wert-Cache im VRAM (spart massig VRAM)
          # OLLAMA_KV_CACHE_TYPE = "q8_0";

          # 3. Verhindert, dass Ollama parallel Slots für mehrere User im VRAM reserviert
          OLLAMA_NUM_PARALLEL = "1";
        };
      };

      # Former ./_update.nix.
      system.autoUpgrade = {
        enable = true;
        #flake = "/etc/nixos";
        #flake = "github:j340m3/nixos";
        flake = inputs.self.outPath;
        flags = [
          "--update-input"
          "nixpkgs"
          "--print-build-logs"
          "--commit-lock-file"
          #  "--upgrade-all"
          #  "--no-write-lock-file"
        ];
        allowReboot = true;
        dates = lib.mkDefault "*-*-* 0/1:45:00";
        randomizedDelaySec = lib.mkDefault "25min";
        #dates = lib.mkDefault "hourly";
        rebootWindow = {
          lower = lib.mkDefault "22:00";
          upper = "08:00";
        };
      };

      boot.kernelPackages = pkgs.linuxPackages_zen;

      systemd.targets.sleep.enable = false;
      systemd.targets.suspend.enable = false;
      systemd.targets.hibernate.enable = false;
      systemd.targets.hybrid-sleep.enable = false;

      #virtualisation.virtualbox.host = {
      #  enable = true;
      #  enableKvm = true;
      #  addNetworkInterface = false;
      #};
      #users.extraGroups.vboxusers.members = [ "user-with-access-to-virtualbox" ];

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

      # Copy the NixOS configuration file and link it from the resulting system
      # (/run/current-system/configuration.nix). This is useful in case you
      # accidentally delete configuration.nix.
      # system.copySystemConfiguration = true;

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

    };
}
