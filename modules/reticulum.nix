{config,lib,pkgs,...}:{
  systemd.services.reticulum = {
    path = with pkgs; [
      rns
    ];
    script = ''
      ${pkgs.rns}/bin/rnsd
    '';
    wantedBy = [ "multi-user.target" ];
  };
}