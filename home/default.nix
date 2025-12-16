{
  pkgs,
  inputs,
  lib,
  ...
}:
{
  imports = [
    inputs.stylix.homeModules.stylix
    ./style.nix
    ./vscode.nix
    ./browser.nix
    ./accounts.nix
    ./xfce
  ];
  home.username = "jeromeb";
  home.homeDirectory = "/home/jeromeb";
  home.stateVersion = "25.11"; # Comment out for error with "latest" version
  #stylix.homeManagerIntegration.autoImport = false;
  #stylix.homeManagerIntegration.followSystem = false;
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    btop
    git
    vulnix
    wezterm
    spotify
    signal-desktop
    telegram-desktop
    element-desktop
    radicle-desktop
    radicle-node
    sops
  ];
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "spotify"
      "apple_cursor"
    ];
}
