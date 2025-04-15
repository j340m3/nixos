{config, lib, pkgs, ...} :{

  services.nebula.networks.mesh = {
    enable = true;
    isLighthouse = false;
    lighthouses = [ "10.0.0.1" ];
    settings = {
        cipher= "aes";
        punchy.punch=true;
        };
    cert = config.sops.secrets."nebula/self.crt".path; #"/run/secrets/nebula/self.crt";
    key = config.sops.secrets."nebula/self.key".path; #"/run/secrets/nebula/self.key";
    ca = config.sops.secrets."nebula/ca.crt".path; #"/run/secrets/nebula/ca.crt";
    staticHostMap = {
        "10.0.0.1" = [
                "194.164.125.154:4242"
                ];
        };
    firewall.outbound = [
      {
        host = "any";
        port = "any";
        proto = "any";
      }
    ];
    firewall.inbound = [
      {
        host = "any";
        port = "any";
        proto = "any";
      }
    ];
  };
  sops.secrets."nebula/ca.crt" = {
    restartUnits = ["nebula@mesh.service"];
    owner = "nebula-mesh";
  };
  sops.secrets."nebula/self.crt" = {
    sopsFile = ../secrets/${config.networking.hostName}/secrets.yaml;
    restartUnits = ["nebula@mesh.service"];
    owner = "nebula-mesh";
  };
  sops.secrets."nebula/self.key" = {
    sopsFile = ../secrets/${config.networking.hostName}/secrets.yaml;
    restartUnits = ["nebula@mesh.service"];
    owner = "nebula-mesh";
  };
}