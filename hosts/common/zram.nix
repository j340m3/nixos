{config,lib,pkgs,...}:{
  zramSwap = {
    enable = true;
    algorithm = lib.mkDefault "lz4";
    memoryPercent = 90;
  };
}