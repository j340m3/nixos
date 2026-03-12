{constants, config, lib, ...}:{
  services.technitium-dns-server = {
    enable = true;
    openFirewall = true;
  };
  networking.firewall.interfaces."nebula.mesh".allowedTCPPorts = [ 53 5380 53443];
  services.nebula.networks.mesh.firewall.inbound = lib.mkIf 
              (config.services.technitium-dns-server.enable && 
              config.services.nebula.networks.mesh.enable) 
      [
        {
          cidr = constants.nebula.cidr;
          port = 5380;
          proto = "any";
        }
        {
          cidr = constants.nebula.cidr;
          port = 53443;
          proto = "any";
        }
      ];
  # networking.firewall.allowedUDPPorts = [
  #   53 # technitium-dns-server
  # ];
  # networking.firewall.allowedTCPPorts = [
  #   53 # technitium-dns-server
  # ];
}
