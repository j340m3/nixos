{ config, pkgs, lib, ...} : {
 /*  imports = [
    ./kde/plasma.nix
  ]; */
  services.xserver.enable = true;

  services = {
    displayManager.sddm.enable = true;
    desktopManager.plasma6.enable = true;
  };
  services.displayManager.sddm.wayland.enable = true;
  
  environment.systemPackages = with pkgs;
    [
      libsForQt5.qtstyleplugin-kvantum
      libsForQt5.qt5ct
  ];

  nixpkgs.config.qt5 = {
    enable = true;
    platformTheme = "qt5ct"; 
      style = {
        package = pkgs.whitesur-kde;
        name = "WhiteSur";
      };
  };

  environment.variables.QT_QPA_PLATFORMTHEME = "qt5ct";
}