{pkgs,...}:{
  system.nixos.tags = [ "jeromeb" ];
  users.users.jeromeb = {
    isNormalUser = true;
    description = "Jerome Bergmann";
    extraGroups = [ "networkmanager" "wheel" ];
    uid = 1001;
    packages = with pkgs; [
      firefox
    #  kate
    #  thunderbird
    ];
  };
}
