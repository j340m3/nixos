{config,lib,pkgs,...}:{
  options = {
    writebackPartition = lib.mkOption {
      type = lib.types.string;
      default = "";
      description = "The writeback partition fro zramSwap.";
    };
  };
  config = {
    zramSwap = {
      enable = true;
      algorithm = lib.mkDefault "lz4";
      memoryPercent = 100;
      writebackPartition = lib.mkIf (config.writebackPartition != "") config.writebackPartition;
    };
    boot.kernel.sysctl = { 
      "vm.swappiness" = lib.mkDefault 180;
      "vm.watermark_boost_factor" = 0;
      "vm.watermark_scale_factor" = 125;
      "vm.page-cluster" = 0;
      "vm.dirty_background_ratio"=1;
      "vm.dirty_ratio"=50;
      "vm.vfs_cache_pressure"=500;
    };
  };
}