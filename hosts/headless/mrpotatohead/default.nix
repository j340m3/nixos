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

    ./disk-config.nix
    ../../../modules/common
    ../../../users/donquezz.nix
    ../../../modules/nebula.nix
    ../../../modules/logging.nix
    ../../../modules/nextcloud.nix

  ];

  sops.age = {
    #keyFile = "/var/lib/sops-nix/key.txt";
    sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519" ];
  };

  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
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

  networking.firewall.enable = true;
  networking.hostName = "mrpotatohead";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "24.05";
}
