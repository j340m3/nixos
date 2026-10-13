{pkgs,...}:{
  environment.systemPackages = [
    pkgs.kitty
    pkgs.gnomeExtensions.activate-linux
  ]; 
  stylix.enable = true;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/flexoki-light.yaml";
}
