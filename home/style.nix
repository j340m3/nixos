{pkgs,inputs,...}:{
  imports = [
    
  ];
  stylix.autoEnable = true;
  stylix.enable = true;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
  programs.dconf.enable = true;
}
