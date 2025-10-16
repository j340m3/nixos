{ config, pkgs, lib, ... }:

{
  gtk = {
    enable = true;
    theme = {
      package = pkgs.whitesur-gtk-theme;
      name = "WhiteSur-dark-solid";
    };
    # iconTheme = {
    #   package = pkgs.whitesur-icon-theme.override {
    #     alternativeIcons = true;
    #     boldPanelIcons = true;
    #   };
    #   name = "WhiteSur";
    # };
    gtk3.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=1
      '';
    };
    gtk4.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=1
      '';
    };
  };

  qt.kvantum.theme = {
    package = pkgs.my.whitesur-kde;
    dir = "WhiteSur-solid";
    name = "WhiteSur-solid";
  };
  stylix.targets.xfce.enable = true;

  programs.gpg.enable = true;

  services.gpg-agent.enable = true;
}
