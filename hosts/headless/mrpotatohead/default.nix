{
  modulesPath,
  lib,
  pkgs,
  inputs,
  ...
}@args:
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.sops-nix.nixosModules.sops
    inputs.nixos-facter-modules.nixosModules.facter
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    (modulesPath + "/profiles/minimal.nix")
    (modulesPath + "/profiles/headless.nix")
    ../../../modules/hardening.nix

    ./disk-config.nix
    ../../../modules/common
    ../../../users/donquezz.nix
    ../../../modules/nebula.nix
    ../../../modules/logging.nix
    ../../../modules/nextcloud.nix

  ];

  sops.age = {
    #keyFile = "/var/lib/sops-nix/key.txt";
    sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
    # menu has to be reachable on the provider console long enough to pick the
    # previous generation when a new kernel does not come up
    extraConfig = ''
      serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1
      terminal_input --append serial
      terminal_output --append serial
    '';
  };
  boot.loader.timeout = 15;
  # headless.nix keeps the kernel on the vga text console, this adds serial
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS0,115200n8"
  ];
  services.openssh.enable = true;

  facter.reportPath =
    if builtins.pathExists ./facter.json then
      ./facter.json
    else
      throw "Have you forgotten to run nixos-anywhere with `--generate-hardware-config nixos-facter ./facter.json`?";

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    # change this to your ssh key
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHFzPnlj9Bwq47kDwdNrapGZInlvZYqYFE/HYcdZWLzv"
  ]
  ++ (args.extraPublicKeys or [ ]); # this is used for unit-testing this module and can be removed if not needed

  # modules/hardening.nix minus two settings that are unsafe on this VPS.
  # forcePageTableIsolation adds pti=on, which panics the boot on a CPU that
  # does not report PTI; this AMD EPYC guest reports smep/smap but no pti.
  # killUnconfinedConfinables kills unconfined processes that enter a confined
  # profile, which is the nginx/php-fpm path nextcloud runs on.
  security.forcePageTableIsolation = false;
  security.apparmor.killUnconfinedConfinables = false;

  # modules/hardening.nix asks for strict reverse path filtering (1), which
  # also drops packets that arrive on a different interface than the route to
  # their source suggests, e.g. over nebula. Loose (2) still rejects spoofed
  # sources. Set both to 1 to go strict.
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.rp_filter" = 2;
    "net.ipv4.conf.default.rp_filter" = 2;
  };

  # logs process execs and writes to privilege files, so a compromised service
  # leaves a trail. failureMode stays printk, no -e 2: nothing to test here.
  security.auditd.enable = true;
  security.audit.rules = [
    "-a exit,always -F arch=b64 -S execve"
    "-w /etc/sudoers -p wa -k identity"
    "-w /etc/ssh/sshd_config -p wa -k identity"
  ];

  networking.firewall.enable = true;
  networking.hostName = "mrpotatohead";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "24.05";

  # ---- Advanced Configuration
  #

  # --- More Memory
  swapDevices = [
    {
      device = "/swapfile";
      size = 4096;
    }
  ];
  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;

  # --- More space
  services.beesd.filesystems = {
    root = {
      hashTableSizeMB = 64;
      spec = "/";
      verbosity = "crit";
      extraOptions = [
        "--loadavg-target"
        "1.0"
      ];
    };
  };
}
