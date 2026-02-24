{...}:{
  boot.kernelModules = [ "iwlwifi" ];
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;
  nixpkgs.config.allowUnfree = true;

  #networking.wireless.enable = true;
  #networking.wireless.userControlled.enable = true;
  networking.useDHCP = false;
}
