# dendritic aspect (ADR 0014): nofile login limits absorbed from _common/ulimit.nix.
_: {
  flake.modules.nixos.ulimit = _: {
    security.pam.loginLimits = [
      {
        domain = "*";
        type = "soft";
        item = "nofile";
        value = "65536";
      }
      {
        domain = "*";
        type = "hard";
        item = "nofile";
        value = "1048576";
      }
    ];
  };
}
