{config,lib,pkgs,...}:{
  systemd.services.reticulum = {
    path = with pkgs; [
      rns
    ];
    script = ''
      ${pkgs.rns}/rnsd
    '';
    wantedBy = [ "multi-user.target" ];
  };
}