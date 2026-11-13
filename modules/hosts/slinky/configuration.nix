# Host aspect (ADR 0014): the module list is assembled by lib.mkNixos
# (modules/nix/lib.nix) from flake.modules.nixos.slinky; the flake-parts.nix
# one-liner next to this file declares the host into the flake.
# inputs close over the head args. Two-file host: the hardware scan result
# plus the uConsole device glue and machine-local secrets are inlined
# below — no host-local glue.
#
# 2026-11-13 (ADR 0019): migrated from nixos-hardware + the oom-hardware fork
# to nixos-raspberrypi + nixos-uconsole. nvmd's lib.nixosSystem wrapper is not
# used (the factory builds hosts with plain nixpkgs.lib.nixosSystem), so its
# wiring — RPi overlays, pkgs.rpi scope and the `nixos-raspberrypi` module
# argument — is replicated here.
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

        # === Raspberry Pi world (nixos-raspberrypi) ===
        # nvmd's modules take the flake as a module argument (e.g. for the
        # firmware/kernel package defaults and uc-4g's pinctrl); the factory
        # has no specialArgs, so `_module.args` provides it.
        { _module.args.nixos-raspberrypi = inputs.nixos-raspberrypi; }
        # Vendor kernel/firmware/bootloader overlays — equivalent of
        # nixos-raspberrypi.lib.nixosSystem's default rpi modules.
        inputs.nixos-raspberrypi.lib.inject-overlays
        inputs.nixos-raspberrypi.nixosModules.nixpkgs-rpi
        inputs.nixos-raspberrypi.nixosModules.raspberry-pi-4.base
        inputs.nixos-raspberrypi.nixosModules.raspberry-pi-4.bluetooth

        # === uConsole (nixos-uconsole) ===
        # All-in-one: kernel patches (CWU50 panel, AXP228, OCP8178 backlight),
        # config.txt defaults, CM4 kernel params, base good defaults,
        # uc-sleep power button, uc-4g module.
        inputs.nixos-uconsole.nixosModules.uconsole-cm4

        inputs.self.modules.nixos.system-default
        inputs.self.modules.nixos.vscodium
        inputs.self.modules.nixos.logging
        inputs.self.modules.nixos.nebula
        inputs.self.modules.nixos.wifi

        # WHY: some modules use the deprecated
        # `environment.checkConfigurationOptions` option path; alias it.
        (lib.mkAliasOptionModule [ "environment" "checkConfigurationOptions" ] [ "_module" "check" ])
      ];

      # WHY: nixpkgs' rename.nix conflicts with nixos-raspberrypi's option
      # names; disable the problematic module (compat fix replicated from
      # nixos-uconsole's mkUConsoleSystem, which is not exported as a module).
      disabledModules = [ (modulesPath + "/rename.nix") ];

      # Generational kernel boot on /boot/firmware (not u-boot/extlinux).
      boot.loader.raspberry-pi.bootloader = "kernel";

      # Inlined from ./_hardware-configuration.nix (zero host-local glue, ADR 0014).
      fileSystems."/" = {
        device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
        fsType = "ext4";
      };

      # The generational raspberry-pi bootloader mounts /boot/firmware during
      # activation, so no noauto/nofail here (sd-image-style options would
      # break `nixos-rebuild`).
      fileSystems."/boot/firmware" = {
        device = "/dev/disk/by-uuid/2178-694E";
        fsType = "vfat";
        options = [
          "fmask=0022"
          "dmask=0022"
        ];
      };

      zramSwap = {
        memoryPercent = 50;
      };
      # Enables DHCP on each ethernet and wireless interface.
      networking.useDHCP = lib.mkDefault true;

      # nixos-raspberrypi v1.20260317.0 reads `stdenv.hostPlatform.linux-kernel`
      # (the kernel image file name), which nixpkgs 26.11 dropped from
      # `lib.systems.elaborate`. Carry the attr through the platform again
      # (pre-26.11 style) so the canonical hostPlatform keeps a single shape
      # for equality comparisons in the cross machinery. The elaborate
      # assertion against it is dormant while nixpkgs 2605 is the oldest
      # supported release. Fixed upstream in nvmd/nixos-raspberrypi main
      # (they branch on the nixpkgs release); drop this when nixos-uconsole
      # moves to a nixos-raspberrypi release carrying the fix.
      nixpkgs.hostPlatform = lib.systems.elaborate {
        system = "aarch64-linux";
        linux-kernel = {
          target = "Image";
        };
      };

      users.groups.spi = { };
      services.udev.extraRules = ''
        SUBSYSTEM=="spidev", KERNEL=="spidev0.0", GROUP="spi", MODE="0660"
      '';

      console = {
        earlySetup = true;
        # nixos-uconsole's base module defaults to ter-v24n; keep the larger
        # font this host has been using on the 720x1280 panel.
        font = lib.mkForce "ter-v32n";
        packages = with pkgs; [ terminus_font ];
      };

      # Extra kernel params kept from the pre-migration config (cm.nix adds
      # 8250.nr_uarts, console=tty1 and the snd_bcm2835 params).
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

      # Device tree / config.txt settings migrated from the oom-hardware
      # setup into nixos-raspberrypi's `hardware.raspberry-pi.config`
      # namespace (rendered into /boot/firmware/config.txt).
      hardware.raspberry-pi.config.cm4 = {
        options = {
          # nvmd's config.txt module defaults cm4 to XHCI host mode
          # (otg_mode=1), but the clockworkpi-uconsole overlay runs with
          # nopcie0 (no PCIe → no XHCI/VL805), so USB goes through dwc2 in
          # host mode below — the same setup slinky ran pre-migration.
          otg_mode.enable = false;
        };
        base-dt-params = {
          # dtparam=spi=off — proven state from the oom-hardware setup (the
          # clockworkpi-uconsole overlay manages its own SPI usage).
          spi = {
            enable = true;
            value = "off";
          };
          # dtparam=i2c_arm=on
          i2c_arm = {
            enable = true;
            value = "on";
          };
        };
        dt-overlays = {
          clockworkpi-uconsole = {
            enable = true;
            params = {
              # cpi-disable-pcie / cpi-disable-genet equivalents
              nopcie0 = {
                enable = true;
                value = true;
              };
              nogenet = {
                enable = true;
                value = true;
              };
            };
          };
          # USB host mode through the dwc2 OTG controller (was
          # configtxt.deviceTreeOverlays.cm4 dwc2.dr_mode=host).
          dwc2 = {
            enable = true;
            params.dr_mode = {
              enable = true;
              value = "host";
            };
          };
          # CPU revision hint for the CM4 (oom-hardware used the same
          # cpu-revision overlay with cm4-8).
          cpu-revision = {
            enable = true;
            params."cm4-8" = {
              enable = true;
              value = "on";
            };
          };
        };
      };

      # oom-hardware's module-4g was imported unconditionally; the
      # nixos-uconsole equivalent ships as an opt-in module.
      hardware.uc-4g.enable = true;

      # Neutralize the image-flavoured defaults from nixos-uconsole's base
      # module (they target a fresh SD-card install, not a managed fleet
      # host): no root password, no root SSH, no forced password rotation.
      users.users.root.initialPassword = lib.mkForce null;
      services.openssh.settings.PermitRootLogin = lib.mkForce "no";
      services.openssh.settings.PasswordAuthentication = lib.mkForce false;
      systemd.services.force-password-change.wantedBy = lib.mkForce [ ];

      networking.hostName = "slinky"; # Define your hostname.
      networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

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

      # rpi-utils ship with nixos-raspberrypi's base module
      # (raspberrypi-utils, built from the vendor tree).
      environment.systemPackages = with pkgs; [
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
        # slinky's kernel reaches woody's harmonia cache via the ADR-0018
        # artifact publisher. The community uConsole cache
        # (cache-nix.project2.xyz) is dead (2026-11-13) and the upstream
        # nixos-clockworkpi-uconsole.cachix.org cache only serves systems
        # built on nixos-uconsole's own nixpkgs-25.11 pin, not this host.
        substituters = [
          "https://cache.chaotic.cx"
        ];
        trusted-substituters = [
          "https://cache.chaotic.cx"
        ];
        trusted-public-keys = [
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
      # ADR 0018: the local "builder-local" machine entry is gone. Its ssh
      # alias was removed with the pre-dendritic tree (commit 425c717), so it
      # always failed and silently forced the local fallback; the fleet
      # builders (distributed-builds aspect via system-default) are the real
      # accelerators and slinky's kernel now reaches a cache through woody's
      # artifact publisher, not through a machine entry.
    };
}
