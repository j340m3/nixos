# Shared core of the bootstrap images (ADR-0015 split): everything the
# btrfs-root and tmpfs-root (impermanent) variants repeat verbatim.
# Layout-specific bits (disko layout, fileSystems, swap) and the per-host
# deltas (nameservers, ssh port, hostname, user blocks) live in the layout
# modules and host files next to this one.
{ inputs, ... }:
{
  flake.modules.nixos.bootstrap-core =
    {
      config,
      lib,
      ...
    }:
    {
      imports = [
        inputs.disko.nixosModules.disko
        inputs.sops-nix.nixosModules.sops
        inputs.self.modules.nixos.agent-md
      ];
      nixpkgs.hostPlatform = "x86_64-linux";
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
      # Install Grub
      boot.loader.grub = {
        enable = !config.boot.isContainer;
        default = "saved";
        devices = lib.mkDefault [ "/dev/vda" ];
      };
      boot.tmp.cleanOnBoot = true;
      zramSwap.enable = true;
      # Timezone, change based on your location
      time.timeZone = "Europe/Berlin";
      # Manage networking with systemd-networkd
      systemd.network.enable = true;
      services.resolved.enable = false;
      # recovery host, ships no logs: keep the journal off disk
      # mkDefault so a service host importing this + logging.nix still evals
      # (plain-vs-plain RuntimeMaxUse conflict killed buzz's toplevel, 2026-10-18)
      services.journald.settings.Journal = {
        Storage = "volatile";
        RuntimeMaxUse = lib.mkDefault "32M";
        ForwardToSyslog = false;
      };
      systemd.tmpfiles.rules = [ "R /var/log/journal" ];
      # Configure network IP and DNS
      systemd.network.networks.eth0 = {
        #address = ["194.164.54.40/24"];
        #gateway = ["194.164.54.1"];
        matchConfig.Name = "eth0";
        networkConfig.DHCP = "yes";
      };
      # Enable SSH server
      services.openssh = {
        enable = true;
        settings = {
          #PasswordAuthentication = false;
          #PermitRootLogin = lib.mkForce "prohibit-password";
        };
      };
      # Disable NixOS's builtin firewall
      networking.firewall.enable = lib.mkDefault false;
      # Disable DHCP and configure IP manually
      networking.useDHCP = false;
      # Latest NixOS version on your first install. Used to prevent backward
      # incompatibilities on major upgrades
      system.stateVersion = lib.mkDefault "25.05";
      # Kernel modules required by QEMU (KVM) virtual machine
      boot.initrd.postDeviceCommands = lib.mkIf (!config.boot.initrd.systemd.enable) ''
        # Set the system time from the hardware clock to work around a
        # bug in qemu-kvm > 1.5.2 (where the VM clock is initialised
        # to the *boot time* of the host).
        hwclock -s
      '';
      boot.initrd.availableKernelModules = [
        "virtio_net"
        "virtio_pci"
        "virtio_mmio"
        "virtio_blk"
        "virtio_scsi"
      ];
      boot.initrd.kernelModules = [
        "virtio_balloon"
        "virtio_console"
        "virtio_rng"
      ];
    };
}
