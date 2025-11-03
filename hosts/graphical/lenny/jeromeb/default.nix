{pkgs,inputs,...}:{
  imports = [
    ../../../../desktop-environments/xfce.nix
    inputs.home-manager.nixosModules.home-manager
  ];
  users.mutableUsers = false;
  system.nixos.tags = [ "jeromeb" ];
  users.users.jeromeb = {
    isNormalUser = true;
    description = "Jerome Bergmann";
    extraGroups = [ "networkmanager" "wheel" ];
    hashedPassword = "$y$j9T$xI3Gvnwn4Q900uL0HQZHp/$fl5oFfnZWZWBz.6gPxvciND13komHHAXDqq6Yfpjn17";
    uid = 1002;
    packages = with pkgs; [
      firefox
    #  kate
    #  thunderbird
    ];
  };
  home-manager.backupFileExtension = "hmbackup";
  home-manager.users.jeromeb = import ../../../home;
  home-manager.extraSpecialArgs = {inherit inputs; };
}
