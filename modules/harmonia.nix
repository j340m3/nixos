{ config, lib, constants, ... }:

let
  domainName = "cache.kauderwels.ch";
in
{
  services.harmonia.cache.enable = true;
  services.harmonia.cache.signKeyPaths = [ "/var/lib/secrets/harmonia.secret" ];
  # no tls_cert_path/tls_key_path: harmonia runs as a DynamicUser with
  # PrivateUsers and cannot read the acme key. nginx terminates TLS and talks
  # to it over localhost instead.
  services.harmonia.cache.settings.bind = "127.0.0.1:5000";

  security.acme.certs.${domainName}.group = config.services.nginx.group;

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts.${domainName} = {
      useACMEHost = domainName;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:5000";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_redirect http:// https://;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        '';
      };
    };
  };

  nix.settings.allowed-users = [ "harmonia" ];
  networking.firewall.interfaces."nebula.mesh".allowedTCPPorts = [ 443 80 ];

  services.nebula.networks.mesh.firewall.inbound = lib.mkIf 
              (config.services.harmonia.cache.enable && 
              config.services.nebula.networks.mesh.enable) 
      [
        {
          cidr = constants.nebula.cidr;
          port = 443;
          proto = "tcp";
        }
        {
          cidr = constants.nebula.cidr;
          port = 80;
          proto = "tcp";
        }
      ];
}
