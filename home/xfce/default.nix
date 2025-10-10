{ config, pkgs, lib, ... }:

{
  gtk = {
    enable = true;
  };
  stylix.targets.xfce.enable = true;

  programs.gpg.enable = true;

  services.gpg-agent.enable = true;
}
