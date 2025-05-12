{
  config,
  lib,
  pkgs,
  inputs,
  ...
} : {
  users.users.peerix = {
    isSystemUser = true;
    group = "peerix";
  };
  users.groups.peerix = {};

  services.peerix = {
    enable = true;
    package = inputs.peerix.packages.${pkgs.system}.peerix;
    user = "peerix";
    group = "peerix";
    #openFirewall = true; # UDP/12304
    privateKeyFile = config.sops.secrets."peerix/private".path;
    #publicKeyFile =  config.sops.secrets."peerix/public".path;
    publicKey = "peerix-woody:A84EBXl0lnyfP/v+IBB4HO7jkpL0OI9PNaY3PqZhW7Q= peerix-rex:CPPA1PQfRIkEpKYZckfRI04p37uIaBz5uKT2ufs/z/U=";
    # example # publicKey = "peerix-laptop:1ZjzxYFhzeRMni4CyK2uKHjgo6xy0=";
  };

  sops.secrets."peerix/public" = {
    sopsFile = ../secrets/${config.networking.hostName}/secrets.yaml;
    #restartUnits = ["nebula@mesh.service"];
    #owner = "nebula-mesh";
    #group = "nebula-mesh";
    #path = "/etc/nebula/self.crt";
  };

  sops.secrets."peerix/private" = {
    sopsFile = ../secrets/${config.networking.hostName}/secrets.yaml;
    #restartUnits = ["nebula@mesh.service"];
    owner = "peerix";
    group = "peerix";
    #path = "/etc/nebula/self.crt";
  };
}