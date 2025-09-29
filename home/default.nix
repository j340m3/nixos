{ pkgs, ... }:
{
  imports = [
    #./style.nix
    ./vscode.nix
    ./browser.nix
    ./accounts.nix
    #./mate
  ];
  home.username = "jeromeb";
  home.homeDirectory = "/home/jeromeb";
  home.stateVersion = "25.11"; # Comment out for error with "latest" version
  programs.home-manager.enable = true;
  home.packages = with pkgs; [
    btop
    git
  ];
}
