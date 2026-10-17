{
  nebula.cidr = "10.0.0.0/24";
  domain = "kauderwels.ch";

  # Remote-build targets over the nebula mesh. A buildHosts entry is what
  # enrolls a host as a build target; the accept side (remotebuild user,
  # trusted-users, authorizedKeys) is automatic for every mesh member
  # (modules/nebula.nix => modules/remote-builder.nix). Enrolling a host =
  # its ssh.pub in secrets/common/ssh/<h>/ (feeds knownHosts), its mesh IP
  # here, and its root key in modules/remote-builder.nix authorizedKeys.
  # Enlisted: the five below. Awaiting address verification: lenny, rex,
  # slinky (ip.nebula values live in secrets/shared.yaml).
  # buildHosts are opportunistic accelerators only; absence means not
  # attempted. Unreachable hosts fall back to local builds (no hard
  # dependency). See ADR-0000.
  buildHosts = {
    pricklepants = {
      connect = "10.0.0.1";
      port = 42069;
      user = "remotebuild";
      systems = [ "x86_64-linux" ];
      speedFactor = 1;
    };
    buzz = {
      connect = "10.0.0.5";
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
      connect = "10.0.0.7";
      port = 42069;
      user = "remotebuild";
      systems = [ "x86_64-linux" ];
      speedFactor = 1;
    };
    woody = {
      connect = "10.0.0.3";
      port = 42069;
      user = "remotebuild";
      systems = [ "x86_64-linux" ];
      speedFactor = 1;
    };
  };
}
