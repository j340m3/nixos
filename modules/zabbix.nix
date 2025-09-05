{
  config,
  lib,
  pkgs,
  ...
}:
{
  networking.firewall.interfaces."nebula.mesh".allowedTCPPorts = [ 10050 10051];
  services.nebula.networks.mesh.firewall.inbound = lib.mkIf 
              (config.services.zabbixAgent.enable && 
              config.services.nebula.networks.mesh.enable) 
      [
        {
          host = "any";
          port = config.services.zabbixAgent.listen.port;
          proto = "any";
        }
      ];
  
  services.zabbixAgent = {
      enable = true;
      package = pkgs.zabbix72.agent;
      server = "10.0.0.3";
      settings = {
        Hostname = "${config.networking.hostName}";
        ServerActive = "10.0.0.3";
      };
    };
}