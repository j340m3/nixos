{config,lib,pkgs,...}:{
  zramSwap = {
    enable = true;
    algorithm = lib.mkDefault "lz4";
    memoryPercent = 90;
  };
  boot.kernel.sysctl = { 
    "vm.swappiness" = lib.mkDefault 180;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.page-cluster" = 0;
  };
}