{config, lib, pkgs, ...} :{
  environment.systemPackages = with pkgs; [
    nebula
  ];

  services.nebula.networks.mesh = {
    listen.host = "[::]";
    enable = true;
    isLighthouse = false;
    lighthouses = [ "10.0.0.1" "10.0.0.5" ];
    relays = [ "10.0.0.1" "10.0.0.5"];
    settings = {
        cipher= "aes";
        static_map = {
          network = "ip";
        };
        punchy = {
          punch = true;
          respond = true;
        };
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
        "10.0.0.5" = [ 
          "194.164.54.40:4242" 
          "[2a01:239:27f:fd00::1]:4242"
        ];
        };
    firewall.outbound = [
      {
        cidr = constants.nebula.cidr;
        port = "any";
        proto = "any";
      }
    ];
    
    firewall.inbound = [
      {
        cidr = constants.nebula.cidr;
        proto = "icmp";
        port = "any";
      }
      /* {
        cidr = constants.nebula.cidr;
        port = "any";
        proto = "any";
      } */
    ];
      /* {
        cidr = constants.nebula.cidr;
        port = "any";
        proto = "any";
      }] 
      ++ lib.optional (config.useComin) ({
        cidr = constants.nebula.cidr;
        port = "4242";
        proto = "any";
      }); */

  };
  sops.secrets."nebula/ca_crt" = {
    restartUnits = ["nebula@mesh.service"];
    owner = "nebula-mesh";
    group = "nebula-mesh";
    path = "/etc/nebula/ca.crt";
  };
  sops.secrets."nebula/self_crt" = {
    sopsFile = ../secrets/${config.networking.hostName}/secrets.yaml;
    restartUnits = ["nebula@mesh.service"];
    owner = "nebula-mesh";
    group = "nebula-mesh";
    path = "/etc/nebula/self.crt";
  };
  sops.secrets."nebula/self_key" = {
    sopsFile = ../secrets/${config.networking.hostName}/secrets.yaml;
    restartUnits = ["nebula@mesh.service"];
    owner = "nebula-mesh";
    group = "nebula-mesh";
    path = "/etc/nebula/self.key";
  };
}