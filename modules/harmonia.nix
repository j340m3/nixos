{
  config,
  lib,
  constants,
  ...
}:

{
  services.harmonia.cache.enable = true;
  services.harmonia.cache.signKeyPaths = [ "/var/lib/secrets/harmonia.secret" ];
  # woody is not reachable from the internet, so Let's Encrypt cannot validate
  # (ACME HTTP-01 fails). Terminate TLS directly with the static wildcard cert
  # instead of routing through nginx + ACME.
  services.harmonia.cache.settings.tls_cert_path =
    "/etc/ssl/certs/kauderwels.ch_ssl_certificate_chain.cer";
  services.harmonia.cache.settings.tls_key_path = "/etc/ssl/certs/_.kauderwels.ch_private_key.key";

  nix.settings.allowed-users = [ "harmonia" ];
  networking.firewall.interfaces."nebula.mesh".allowedTCPPorts = [
    443
    80
    5000
  ];

  services.nebula.networks.mesh.firewall.inbound =
    lib.mkIf (config.services.harmonia.cache.enable && config.services.nebula.networks.mesh.enable)
      [
        {
          cidr = constants.nebula.cidr;
          port = 5000;
          proto = "tcp";
        }
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

  # cache reachable over the yggdrasil backup overlay — TLS only (no 80/5000)
  networking.firewall.interfaces."ygg".allowedTCPPorts = lib.mkIf (
    config.services.harmonia.cache.enable && config.services.yggdrasil.enable
  ) [ 443 ];

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
}
