{pkgs,...}:{
  system.nixos.tags = [ "lilly" ];
  users.users.lilly = {
    uid = 1001;
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
      #(makeAutostartItem { name = "signal"; package = signal-desktop; }) #TODO: makeAutostartItem is not reachable
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
  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
}
