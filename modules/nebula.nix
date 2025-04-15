{config, lib, pkgs, ...} :{
  environment.systemPackages = with pkgs; [
    nebula
  ];

  services.nebula.networks.mesh = {
    enable = true;
    isLighthouse = false;
    lighthouses = [ "10.0.0.1" ];
    relays = [ "10.0.0.1" ];
    settings = {
          cipher= "aes";
          punchy.punch=true;
          dns = {
            host = "10.0.0.1";
            port = 53;
          };
        };
    cert = config.sops.secrets."nebula/self_crt".path; #"/run/secrets/nebula/self.crt";
    key = config.sops.secrets."nebula/self_key".path; #"/run/secrets/nebula/self.key";
    ca = config.sops.secrets."nebula/ca_crt".path; #"/run/secrets/nebula/ca.crt";
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
  sops.secrets."nebula/ca_crt" = {
    restartUnits = ["nebula@mesh.service"];
    owner = "nebula-mesh";
  };
  sops.secrets."nebula/self_crt" = {
    sopsFile = ../secrets/${config.networking.hostName}/secrets.yaml;
    restartUnits = ["nebula@mesh.service"];
    owner = "nebula-mesh";
  };
  sops.secrets."nebula/self_key" = {
    sopsFile = ../secrets/${config.networking.hostName}/secrets.yaml;
    restartUnits = ["nebula@mesh.service"];
    owner = "nebula-mesh";
  };
}