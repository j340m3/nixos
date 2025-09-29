{pkgs,inputs,lib,...}:{
  imports = [
    
  ];
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "apple_cursor"
  ];

  stylix.autoEnable = true;
  stylix.enable = true;
  #stylix.homeManagerIntegration.followSystem = false;
  #stylix.homeManagerIntegration.autoImport = false;
  stylix.base16Scheme = "${inputs.tinted-schemes}/base16/da-one-paper.yaml";
  #stylix.polarity = "dark";
  stylix.fonts = {
    monospace = {
      package = pkgs.nerd-fonts.victor-mono;
      name = "VictorMono Nerd Font Mono";
    };
    sansSerif = {
      package = inputs.apple-fonts.packages.${pkgs.system}.sf-pro-nerd;
      name = "SFProDisplay Nerd Font";
    };
    serif = {
      package = inputs.apple-fonts.packages.${pkgs.system}.sf-pro-nerd;
      name = "SFProDisplay Nerd Font";
    };
    emoji = {
      package = pkgs.noto-fonts-emoji;
      name = "Noto Color Emoji";
    };
  };
  stylix.cursor = {
    name = "macOS";
    package = pkgs.apple-cursor;
    size = 36;
  };
  stylix.icons = {
    enable = true;
    package = pkgs.whitesur-icon-theme;
    dark = "WhiteSur-dark";
    light = "WhiteSur-light";
  };

}
