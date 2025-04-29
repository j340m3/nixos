{ config, pkgs, lib, ...} : {

  services.xserver.enable = true;

  services = {
    displayManager.sddm.enable = true;
    desktopManager.plasma6.enable = true;
  };

  environment.systemPackages = with pkgs;
    [
      libsForQt5.qtstyleplugin-kvantum
      libsForQt5.qt5ct
  ];
  
  nixpkgs.config.qt5 = {
    enable = true;
    platformTheme = "qt5ct"; 
      style = {
        package = pkgs.utterly-nord-plasma;
        name = "Utterly Nord Plasma";
      };
  };

  environment.variables.QT_QPA_PLATFORMTHEME = "qt5ct";
}