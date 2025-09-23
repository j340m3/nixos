{pkgs,...}: {
    imports = [
        ./vscode.nix
        ./browser.nix
    ];
    home.username = "jeromeb";
    home.homeDirectory = "/home/jeromeb";    
    home.stateVersion = "25.11"; # Comment out for error with "latest" version
    programs.home-manager.enable = true;
}