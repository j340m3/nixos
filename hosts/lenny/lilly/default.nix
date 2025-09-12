{pkgs,...}:{
  system.nixos.tags = [ "lilly" ];
  uid = 1001;
  users.users.lilly = {
    isNormalUser = true;
    description = "Lilly Bergmann";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      tipp10
      libreoffice-qt
      anki
      jetbrains.pycharm-community
      pinta
      krita
      arduino
      lynx
    #  kdenlive
      signal-cli
      signal-desktop
      (makeAutostartItem { name = "signal"; package = signal-desktop; })
      firefox
      kdePackages.kalk
      spotify
      cutechess
      stockfish
      minetest
      flatpak
    #  kalk
    #  kate
    #  thunderbird
    ];
  };
  services.flatpak.enable = true;
  systemd.services.flatpak-repo = {
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };
}
