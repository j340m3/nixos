{pkgs,inputs,...}:{
  imports = [
    ../../../desktop-environments/xfce.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  system.nixos.tags = [ "jeromeb" ];
  users.users.jeromeb = {
    isNormalUser = true;
    description = "Jerome Bergmann";
    extraGroups = [ "networkmanager" "wheel" ];
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
