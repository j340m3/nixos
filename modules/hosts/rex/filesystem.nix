{
  flake.modules.nixos.rex = {
  fileSystems."/" =
      { device = "/dev/disk/by-uuid/ab0899ec-d5b7-4642-be38-577ac223712d";
        fsType = "ext4";
        autoResize = true;
      };

    fileSystems."/boot" =
      { device = "/dev/disk/by-uuid/3B75-1995";
        fsType = "vfat";
        options = [ "fmask=0077" "dmask=0077" ];
      };
  };
}
