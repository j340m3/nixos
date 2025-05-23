{
  config,
  lib,
  pkgs,
  ...
}:
{
  networking.firewall.interfaces."nebula.mesh".allowedTCPPorts = [ 10050 ];
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