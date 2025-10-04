{ config, pkgs, lib, ... }:

{
  gtk = {
    enable = true;
  };

  programs.gpg.enable = true;

  services.gpg-agent.enable = true;
}