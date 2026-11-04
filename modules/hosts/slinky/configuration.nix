# Host aspect (ADR 0014): the module list is assembled by lib.mkNixos
# (modules/nix/lib.nix) from flake.modules.nixos.slinky; the flake-parts.nix
# one-liner next to this file declares the host into the flake.
# inputs close over the head args. Two-file host: the hardware scan result
# plus the uConsole device glue and machine-local secrets are inlined
# below — no host-local glue.
{ inputs, lib, ... }:

{
  flake.modules.nixos.slinky =
    {
      modulesPath,
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [
        # Inlined from ./_hardware-configuration.nix.
        (modulesPath + "/installer/scan/not-detected.nix")
        # Include uConsole settings
        inputs.nixos-hardware.nixosModules.raspberry-pi-4
        # oom-hardware's uconsole module still sets hardware.raspberry-pi.4.dwc2,
        # which nixos-hardware removed, so import its parts directly
        "${inputs.oom-hardware}/uconsole/kernel"
        "${inputs.oom-hardware}/raspberry-pi/overlays"
        "${inputs.oom-hardware}/raspberry-pi/apply-overlays"
        "${inputs.oom-hardware}/uconsole/module-4g.nix"
        inputs.self.modules.nixos.system-default
        inputs.self.modules.nixos.vscodium
        inputs.self.modules.nixos.logging
        inputs.self.modules.nixos.nebula
        inputs.self.modules.nixos.wifi
      ];

      # Inlined from ./_hardware-configuration.nix (zero host-local glue, ADR 0014).
      fileSystems."/" = {
        device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
        fsType = "ext4";
      };

      fileSystems."/boot/firmware" = {
        device = "/dev/disk/by-uuid/2178-694E";
        fsType = "vfat";
        options = [
          "fmask=0022"
          "dmask=0022"
          "nofail"
          "noauto"
        ];
      };

      zramSwap = {
        enable = true;
        algorithm = "lz4";
        memoryPercent = 50;
      };
      # Enables DHCP on each ethernet and wireless interface.
      networking.useDHCP = lib.mkDefault true;

      # Inlined from ./_uConsole.nix (zero host-local glue, ADR 0014).
      nixpkgs.overlays = [
        (_final: super: {
          makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
        })
      ];

      users.groups.spi = { };
      services.udev.extraRules = ''
        SUBSYSTEM=="spidev", KERNEL=="spidev0.0", GROUP="spi", MODE="0660"
      '';

      console = {
        earlySetup = true;
        font = "ter-v32n";
        packages = with pkgs; [ terminus_font ];
      };

      boot.kernelParams = [
        "8250.nr_uarts=1"
        "vc_mem.mem_base=0x3ec00000"
        "vc_mem.mem_size=0x20000000"
        "console=ttyS0,115200"
        "console=tty1"
        "plymouth.ignore-serial-consoles"
        "snd_bcm2835.enable_hdmi=1"
        "snd_bcm2835.enable_headphones=1"
        "psi=1"
        "iommu=force"
        "iomem=relaxed"
        "swiotlb=131072"
      ];

      hardware.raspberry-pi."4" = {
        xhci.enable = false;
        overlays = {
          cpu-revision.enable = true;
          audremap.enable = true;
          vc4-kms-v3d.enable = true;
          cpi-disable-pcie.enable = true;
          cpi-disable-genet.enable = true;
          cpi-uconsole.enable = true;
          cpi-i2c1.enable = false;
          cpi-spi4.enable = false;
          cpi-bluetooth.enable = true;
        };
      };

      # dwc2 moved out of hardware.raspberry-pi.4 into the firmware config
      boot.loader.generic-extlinux-compatible.useGenerationDeviceTree = false;
      hardware.raspberry-pi.configtxt = {
        settings.cm4.otg_mode = null;
        deviceTreeOverlays.cm4 = [
          {
            dwc2.dr_mode = "host";
          }
        ];
      };

      hardware.deviceTree = {
        enable = true;
        filter = "bcm2711-rpi-cm4.dtb";
        overlaysParams = [
          {
            name = "bcm2711-rpi-cm4";
            params = {
              ant2 = "on";
              audio = "on";
              spi = "off";
              i2c_arm = "on";
            };
          }
          {
            name = "cpu-revision";
            params = {
              cm4-8 = "on";
            };
          }
          {
            name = "audremap";
            params = {
              pins_12_13 = "on";
            };
          }
          {
            name = "vc4-kms-v3d";
            params = {
              cma-384 = "on";
              nohdmi1 = "on";
            };
          }
        ];
      };

      # oom-hardware builds its kernel from linux_rpi4, which nixpkgs dropped.
      boot.kernelPackages = lib.mkForce (
        pkgs.linuxPackagesFor (
          pkgs.callPackage "${inputs.nixos-hardware}/raspberry-pi/common/kernel.nix" { rpiVersion = 4; }
        )
      );

      # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
      boot.loader.grub.enable = false;
      # Enables the generation of /boot/extlinux/extlinux.conf
      boot.loader.generic-extlinux-compatible.enable = true;

      networking.hostName = "slinky"; # Define your hostname.
      networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

      # Set your time zone.
      time.timeZone = "Europe/Berlin";

      # Select internationalisation properties.
      i18n.defaultLocale = "de_DE.UTF-8";

      # Enable the X11 windowing system.
      services.xserver.enable = true;
      services.xserver.desktopManager.xfce.enable = true;
      services.displayManager.defaultSession = "xfce";
      services.displayManager.sddm.enable = true;
      services.displayManager.autoLogin = {
        enable = true;
        user = "j340m3";
      };
      # Configure keymap in X11
      services.xserver.xkb.layout = "us";
      services.xserver.xkb.options = "eurosign:e,caps:escape";

      programs.waybar.enable = true;

      # rpi-utils came from ./_uConsole.nix (inlined; ADR 0014).
      environment.systemPackages = with pkgs; [
        (pkgs.callPackage "${inputs.oom-hardware}/raspberry-pi/packages/rpi-utils" { })
        # Former ./_local.nix:
        wirelesstools
        iw
        gitMinimal
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
        rofi
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

      system.stateVersion = "25.05";



      # Inlined from ./_local.nix (zero host-local glue, ADR 0014).
      nix.settings = {
        substituters = [
          "https://cache-nix.project2.xyz/uconsole"
          "https://cache.chaotic.cx"
        ];
        trusted-substituters = [
          "https://cache-nix.project2.xyz/uconsole"
          "https://cache.chaotic.cx"
        ];
        trusted-public-keys = [
          "uconsole:vvqOLjqEwTJBUqv1xdndD1YHcdlMc/AnfAz4V9Hdxyk="
          "chaotic.cachix.org-1:Zf7C6GVRqJjU8B/ihd+psPVKp3/7Or/FSvOP3/9aB8Y="
        ];

        experimental-features = [
          "nix-command"
          "flakes"
        ];
      };
      services.openssh.enable = true;
      boot.supportedFilesystems.zfs = false;

      sops.secrets."users/j340m3/password_hash" = {
        sopsFile = ../../../secrets/hosts/slinky/secrets.yaml;
        neededForUsers = true;
      };

      # Managed declaratively so a password rotation applies on rebuild:
      # mutableUsers = true (the default) leaves an existing password untouched.
      users.mutableUsers = false;

      users.users.j340m3 = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "networkmanager"
        ];
        hashedPasswordFile = config.sops.secrets."users/j340m3/password_hash".path;
        packages = with pkgs; [
          firefox
          signal-desktop
        ];
      };

      nix.settings.max-jobs = 1;
      nix.settings.cores = 1;
      nix.distributedBuilds = true;
      nix.settings.builders-use-substitutes = true;
      nix.buildMachines = [
        {
          hostName = "builder-local";
          sshUser = "remotebuild";
          sshKey = "/root/.ssh/remotebuild";
          systems = [
            "x86_64-linux"
            "aarch64-linux"
          ];
          #system = pkgs.stdenv.hostPlatform.system;
          speedFactor = 100;
          protocol = "ssh-ng";
          supportedFeatures = [
            "nixos-test"
            "big-parallel"
            "kvm"
            "benchmark"
          ];
          maxJobs = 20;
        }
      ];
    };
}
