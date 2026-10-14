{
  pkgs,
  inputs,
  ...
}:
{
  environment.systemPackages = [
    pkgs.kitty
    pkgs.gnomeExtensions.activate-linux
  ];
  stylix.enable = true;
  stylix.base16Scheme = "${inputs.tinted-schemes}/base16/flexoki-light.yaml";
}
