# KDE Plasma 6 desktop with WhiteSur theming.
{
  flake.modules.nixos.kde = { pkgs, ... }: {
    services.xserver.enable = true;

    services = {
      desktopManager.plasma6.enable = true;
    };

    environment.systemPackages = with pkgs; [
      libsForQt5.qtstyleplugin-kvantum
      libsForQt5.qt5ct
      whitesur-kde
      whitesur-cursors
      whitesur-icon-theme
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
  };
}
