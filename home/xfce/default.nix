{ config, pkgs, lib, ... }:

{
  gtk = {
    enable = true;
    theme = {
      package = lib.mkForce pkgs.whitesur-gtk-theme;
      name = lib.mkForce "WhiteSur-Dark";
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

  home.sessionVariables.GTK_THEME = "WhiteSur-Dark";

  stylix.targets.xfce.enable = true;
  
  programs.gpg.enable = true;

  services.gpg-agent.enable = true;

  # xfce-terminal use system font
  programs.xfconf.enable = true; #https://github.com/NixOS/nixpkgs/issues/256428
}
