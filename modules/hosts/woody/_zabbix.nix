{ pkgs, ... }:

{
  networking.firewall.interfaces."nebula.mesh".allowedTCPPorts = [
    80
    443
    8080
    10051
  ];
  #services.zabbixServer ={
  #  enable = true;
  #  package = pkgs.zabbix74.server;
  #};

  services.zabbixWeb = {
    enable = true;
    #    server.port = 8080;
    frontend = "nginx";
    package = pkgs.zabbix74.web;
    nginx.virtualHost = {
      #hostName = "woody";
      #adminAddr = "webmaster@localhost";
      listen = [
        {
          addr = "0.0.0.0";
          port = 80;
          ssl = false;
        }
      ];
    };
  };

  services.zabbixAgent = {
    enable = true;
    server = "localhost";
    package = pkgs.zabbix74.agent;
    #    settings = {
    #      Plugins.MQTT.Session.iot = {
    #        User = "root";
    #        Password = "<redacted, see sops mosquitto-password>";
    #        Topic = "#";
    #      };
    #    };
  };
}
