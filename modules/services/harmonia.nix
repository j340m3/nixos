{ inputs, ... }:
{
  flake.modules.nixos.harmonia =
    {
      config,
      lib,
      ...
    }:
    let
      acmeSecretFile = ../../secrets/services/harmonia/secrets.yaml;
      acmeEnabled = builtins.pathExists acmeSecretFile;
      acmeCertDir = "/var/lib/acme/cache.kauderwels.ch";
    in
    {
      imports = [ inputs.self.modules.nixos.acme ];

      services.harmonia.cache.enable = true;
      services.harmonia.cache.signKeyPaths = [ "/var/lib/secrets/harmonia.secret" ];
      # woody is not reachable from the internet, so HTTP-01 cannot work.  DNS-01
      # needs no inbound port; the IONOS API key lives in the service-scoped sops
      # file.  Until that file exists, keep the manual wildcard so a checkout still
      # evaluates.
      services.harmonia.cache.settings.tls_cert_path =
        if acmeEnabled then
          "/run/credentials/harmonia.service/tls-cert"
        else
          "/etc/ssl/certs/kauderwels.ch_ssl_certificate_chain.cer";
      services.harmonia.cache.settings.tls_key_path =
        if acmeEnabled then
          "/run/credentials/harmonia.service/tls-key"
        else
          "/etc/ssl/certs/_.kauderwels.ch_private_key.key";

      sops.secrets."acme/ionos_api_key" = lib.mkIf acmeEnabled {
        sopsFile = acmeSecretFile;
      };

      security.acme.certs."cache.kauderwels.ch" = lib.mkIf acmeEnabled
        (inputs.self.lib.acmeDns01 config.sops.secrets."acme/ionos_api_key".path {
          reloadServices = [ "harmonia.service" ];
        });

      systemd.services.harmonia.wants = lib.mkIf acmeEnabled [
        "acme-cache.kauderwels.ch.service"
      ];
      systemd.services.harmonia.after = lib.mkIf acmeEnabled [
        "acme-cache.kauderwels.ch.service"
      ];
      systemd.services.harmonia.serviceConfig.LoadCredential = lib.mkIf acmeEnabled [
        "tls-cert:${acmeCertDir}/fullchain.pem"
        "tls-key:${acmeCertDir}/key.pem"
      ];

      nix.settings.allowed-users = [ "harmonia" ];
      networking.firewall.interfaces."nebula.mesh".allowedTCPPorts = [
        443
        80
        5000
      ];

      mesh.openInbound =
        lib.mkIf config.services.harmonia.cache.enable
          [
            {
              port = 5000;
              proto = "tcp";
            }
            {
              port = 443;
              proto = "tcp";
            }
            {
              port = 80;
              proto = "tcp";
            }
          ];

      # harmonia.socket goes zombie after every autoUpgrade config change
      # ("Unit configuration changed ... no socket file descriptors are open;
      # Unit not functional until restarted") — systemd leaves changed socket
      # units dangling, and hourly floating-lock deploys make that every cycle.
      # Run the daemon straight at boot instead (TLS on :5000, in-process).
      systemd.sockets.harmonia.enable = false;
      systemd.services.harmonia.wantedBy = [ "multi-user.target" ];
      systemd.services.harmonia.requires = lib.mkForce [ ];
      # nixpkgs' hardening assumes socket activation: AF_UNIX only, its own
      # network namespace, and IPAddressDeny=any.  Now that the daemon binds
      # [::]:5000 itself, those settings make bind() fail with EAFNOSUPPORT.
      systemd.services.harmonia.serviceConfig = {
        PrivateNetwork = lib.mkForce false;
        IPAddressDeny = lib.mkForce [ ];
        RestrictAddressFamilies = lib.mkForce [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
      };
    };
}
