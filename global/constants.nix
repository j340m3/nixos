{
  nebula.cidr = "10.0.0.0/24";
  domain = "kauderwels.ch";

  # Declaratively-enrolled builder hosts with a statically-known address.
  # `connect` is OPTIONAL: nix.buildMachines only materializes for hosts
  # carrying it (see T4). Hosts without a known address today (jessie, lenny,
  # mrpotatohead, slinky, zurg, rex, woody) are enrolled in T4 after host-key
  # publish + address verification.
  # buildHosts are opportunistic accelerators only; absence means not
  # attempted. Unreachable hosts fall back to local builds (no hard dependency).
  # See ADR-0000.
  buildHosts = {
    pricklepants = {
      connect = "10.0.0.5";
      port = 42069;
      user = "remotebuild";
      systems = [ "x86_64-linux" ];
      speedFactor = 1;
    };
    buzz = {
      connect = "10.0.0.1";
      port = 42069;
      user = "remotebuild";
      systems = [ "x86_64-linux" ];
      speedFactor = 1;
    };
    mrpotatohead = {
      connect = "10.0.0.6";
      port = 42069;
      user = "remotebuild";
      systems = [ "x86_64-linux" ];
      speedFactor = 1;
    };
    jessie = {
      connect = "10.0.0.2";
      port = 42069;
      user = "remotebuild";
      systems = [ "x86_64-linux" ];
      speedFactor = 1;
    };
  };
}
