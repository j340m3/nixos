# Host aspect (ADR 0014): the module list is assembled by lib.mkNixos
# (modules/nix/lib.nix) from flake.modules.nixos.jessie; the flake-parts.nix
# one-liner next to this file declares the host into the flake.
# inputs/constants close over the head args. Two-file host: the hardware
# scan result is inlined below — no host-local glue.
{ inputs, lib, ... }:

{
  flake.modules.nixos.jessie =
    {
      config,
      lib,
      pkgs,
      modulesPath,
      ...
    }:
    {
      imports = [
        # Inlined from ./_hardware-configuration.nix.
        (modulesPath + "/profiles/qemu-guest.nix")
        (modulesPath + "/profiles/minimal.nix")
        (modulesPath + "/profiles/headless.nix")
        inputs.self.modules.nixos.vps-guest
        inputs.self.modules.nixos.hardening
        inputs.self.modules.nixos.system-default
        # ADR 0018: artifact-first updates (substitute woody's prebuilt
        # closure; local-eval fallback preserved on any failure).
        inputs.self.modules.nixos.artifact-update
        inputs.self.modules.nixos.donquezz
        inputs.self.modules.nixos.logging
        inputs.self.modules.nixos.persistence
        # roster lighthouse -> the lighthouse flavor (relay enabled, empty
        # lighthouse/relay self-lists) instead of the plain member aspect
        inputs.self.modules.nixos.nebula-lighthouse
        inputs.self.modules.nixos.minecraft-bedrock
        inputs.self.modules.nixos.wireguard
        inputs.self.modules.nixos.minecraft-java
        inputs.self.modules.nixos.acme
        inputs.self.modules.nixos.radicle-seed
      ];

      # Inlined from ./_hardware-configuration.nix (zero host-local glue, ADR 0014).
      boot.initrd.availableKernelModules = [
        "ata_piix"
        "uhci_hcd"
        "virtio_pci"
        "virtio_blk"
      ];
      boot.kernelModules = [
        "kvm-amd"
        # netavark builds the podman network bridge with a netlink RTM_NEWLINK, and
        # the kernel answers EOPNOTSUPP unless CONFIG_BRIDGE is loaded. It has to be
        # in this list rather than modprobed on demand: kernel.modules_disabled is
        # 1 on this host, so nothing can be inserted after boot.
        "bridge"
      ];

      # Kernel parameters I use
      boot.kernelParams = [
        # Disable auditing
        "audit=0"
        # Do not generate NIC names based on PCIe addresses (e.g. enp1s0, useless for VPS)
        # Generate names based on orders (e.g. eth0)
        "net.ifnames=0"
      ];

      # My Initrd config, enable ZSTD compression and use systemd-based stage 1 boot
      boot.initrd = {
        compressor = "zstd";
        compressorArgs = [
          "-19"
          "-T0"
        ];
        systemd.enable = true;
      };

      # / used to be a 4G tmpfs. that tmpfs filled up completely (4.0G used, 0
      # available), because /var/log/journal and rsyslog's files both land under
      # /var/log, which is tmpfs pages: unswappable ram with no swap configured.
      # root is now a subvolume of the same btrfs that holds /nix, so / survives a
      # reboot and logs live on disk. the subvolume has to exist once, by hand:
      #   sudo btrfs subvolume create /nix/@root
      # mount /nix is the top level of the same device, and systemd orders it after
      # / via RequiresMountsFor, so the two mounts of one device are fine.
      fileSystems."/" = {
        device = "/dev/vda3";
        fsType = "btrfs";
        options = [
          "subvol=@root"
          "compress-force=zstd"
          "nosuid"
          "nodev"
        ];
      };

      fileSystems."/nix" = {
        device = "/dev/vda3";
        fsType = "btrfs";
        options = [
          "compress-force=zstd"
          "nosuid"
          "nodev"
        ];
      };

      fileSystems."/boot" = {
        device = "/dev/vda2";
        fsType = "vfat";
        options = [
          "fmask=0077"
          "dmask=0077"
        ];
      };

      services.btrfs.autoScrub = {
        enable = true;
        interval = "weekly";
      };

      services.beesd.filesystems = {
        root = {
          hashTableSizeMB = 64;
          spec = "/nix";
          verbosity = "crit";
          extraOptions = [
            "--loadavg-target"
            "1.0"
          ];
        };
      };

      swapDevices = [
        {
          device = "/nix/persist/swapfile";
          size = 4096;
        }
      ];

      # Enables DHCP on each ethernet and wireless interface.
      networking.useDHCP = lib.mkDefault true;

      #system.autoUpgrade.dates = lib.mkForce "daily";
      #nix.gc.dates = lib.mkForce "daily";

      # Use the GRUB 2 boot loader.
      boot.loader.grub.enable = true;
      boot.loader.grub.default = "saved";
      boot.loader.grub.devices = [ "/dev/vda" ];
      networking.hostName = "jessie"; # Define your hostname.
      # zram re-enabled (ADR 0018): the disable was a leftover of the long-gone
      # tmpfs era (/ has been btrfs @root since the incident below), and
      # compressed-RAM swap ahead of the 4G swapfile is what a 1-core/1.8GB
      # box wants during rebuilds.
      zramSwap = {
        enable = true;
        memoryPercent = 50;
      };
      # 1-core/1.8GB host shared with the minecraft container: nix builds (remote
      # ones arrive via the remotebuild SSH session) run at low priority and one
      # at a time, so bedrock_server wins CPU under contention.
      # Hard CPUQuota would idle the core whenever the game is quiet — avoided.
      nix = {
        daemonCPUSchedPolicy = "idle";
        settings.max-jobs = lib.mkForce 1;
      };
      security.pam.loginLimits = [
        {
          domain = "remotebuild";
          item = "nice";
          value = 15;
        }
      ];
      # autoUpgrade runs as root and bypasses nix-daemon, so nice it separately.
      systemd.services.nixos-upgrade.serviceConfig.Nice = 15;

      # ADR 0018: update by substituting woody's prebuilt closure instead of
      # evaluating the flake on this 1-core box.
      artifactUpdate.enable = true;

      networking.firewall.enable = true;

      system.stateVersion = "25.05";

      # upgradeHealth.enable = true comes from inputs.self.modules.nixos.vps-guest.
    };
}
