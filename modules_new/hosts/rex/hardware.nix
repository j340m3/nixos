{
  flake.modules.nixos.rex = {
    boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "sd_mod" ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ ];
    boot.extraModulePackages = [ ];
    nixpkgs.hostPlatform = "x86_64-linux";
  };
}
