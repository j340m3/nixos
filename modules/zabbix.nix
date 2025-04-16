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
      server = "10.0.0.0/24";
      settings = {
        Hostname = "${config.networking.hostName}";
      };
    };
}