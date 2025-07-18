# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/profiles/qemu-guest.nix")
    ];

  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_blk" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

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
    compressorArgs = ["-19" "-T0"];
    systemd.enable = true;
  };

  # Install Grub
  boot.loader.grub = {
    enable = !config.boot.isContainer;
    default = "saved";
    devices = ["/dev/vda"];
  };

  fileSystems."/" =
    { 
      device = "tmpfs";
      fsType = "tmpfs";
      options = ["relatime" "mode=755" "nosuid" "nodev" "size=3G"];
    };

  fileSystems."/nix" =
    { 
      #device = "/dev/disk/by-uuid/f014f8cb-3fe0-454b-b235-0ce296c4bf32";
      device = "/dev/vda3";
      fsType = "btrfs";
      options = ["compress-force=zstd" "nosuid" "nodev"];
    };

  fileSystems."/boot" =
    { 
      device = "/dev/vda2";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };

  swapDevices = [ { device = "/nix/persist/swapfile"; size = 2048; } ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eth0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}