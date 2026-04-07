{
  flake.modules.nixos.pricklepants = {
    fileSystems."/" = {
      device = "/dev/vda1";
      fsType = "ext4";
    };
    swapDevices = [
      {
        device = "/dev/vda16";
        randomEncryption.enable = true;
      }
    ];
  };
}
