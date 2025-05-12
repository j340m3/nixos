{
  config,
  lib,
  pkgs,
  ...
} : {
  services.peerix = {
    enable = true;
    package = peerix.packages.x86_64-linux.peerix;
    #openFirewall = true; # UDP/12304
    privateKeyFile = config.sops.secrets."peerix/private".path;
    publicKeyFile =  config.sops.secrets."peerix/public".path;
    #publicKey = "THE CONTENT OF peerix-public FROM THE OTHER COMPUTER";
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
    #owner = "nebula-mesh";
    #group = "nebula-mesh";
    #path = "/etc/nebula/self.crt";
  };
}