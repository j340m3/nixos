{config, lib, pkgs, ...}:
{
  services.iodine.server = {
    enable = true;
    domain = "t.kauderwels.ch";
    ip = "10.70.1.1/24";
    extraConfig = "-c";
    passwordFile = config.sops.secrets."iodine".path;
  };

  sops.secrets."iodine" = {
    #rstartUnits = ["nebula@mesh.service"];
    owner = "iodined";
    group = "iodined";
    #path = "/etc/nebula/ca.crt";
  };

  networking.firewall.allowedUDPPorts = [ 53 ];

  networking.nat = {
    enable = true;
    internalInterfaces = [
      "dns0" # iodine
    ];
    externalInterfaces = [
      "ens6"
    ];
  };
}