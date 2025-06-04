{config, lib, pkgs, ...}:
{
  services.iodine.server = {
    enable = true;
    domain = "t.kauderwels.ch";
    ip = "10.70.1.1";
    passwordFile = config.sops.secrets."iodine".path;
  };

  sops.secrets."iodine" = {
    #rstartUnits = ["nebula@mesh.service"];
    owner = "iodined";
    group = "iodined";
    #path = "/etc/nebula/ca.crt";
  };

}