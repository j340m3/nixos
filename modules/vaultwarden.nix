{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  services.vaultwarden.enable = true;

  services.nginx = {
    enable = true;
    
    # Use recommended settings
    recommendedGzipSettings = true;

    virtualHosts."kauderwels.ch" = {
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8000";
      };
    };
  };
}
