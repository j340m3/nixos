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

  services.picom = {
    enable = true;
    shadow = false;
    shadowOpacity = 0.75;

    settings = {
      corner-radius = 10.0;
      rounded-corners-exclude = [
        "class_g = 'awesome'"
        "class_g = 'URxvt'"
        "class_g = 'XTerm'"
        "class_g = 'kitty'"
        "class_g = 'Alacritty'"
        "class_g = 'Polybar'"
        "class_g = 'code-oss'"
        "class_g = 'firefox'"
        "class_g = 'Conky'"
        "class_g = 'Thunderbird'"
        "class_g ?= 'xfce4-panel' && window_type = 'dock'"
      ];
      shadow-radius = 7;
    };
  };

  programs.rofi = {
    enable = true;
    modes = [
      "rofi"
    ];
    theme = lib.mkForce "launchpad";    
  };
}
