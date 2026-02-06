{pkgs, inputs,...}:{
  users.users.jeromeb = {
    isNormalUser = true;
    description = "Jerome";
    extraGroups = [ "networkmanager" "wheel" "docker"];
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;
  services.yubikey-agent.enable = true;
  services.udev.packages = [ pkgs.libfido2 ];
  # Install firefox.
  home-manager.backupFileExtension = "hmbackup";
  home-manager.users.jeromeb = import ../../../home;
  home-manager.extraSpecialArgs = {inherit inputs; };
}
