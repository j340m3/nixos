{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  services.vaultwarden.enable = true;
  security.acme.defaults.email = "j340m3@kauderwels.ch";
  security.acme.acceptTerms = true;

  services.nginx = {
    enable = true;
    
    # Use recommended settings
    recommendedGzipSettings = true;

    virtualHosts."kauderwels.ch" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8000";
      };
    };
};
}
