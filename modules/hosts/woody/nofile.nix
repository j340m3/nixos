{ lib, ... }:

{
  systemd.settings.Manager = {
    DefaultLimitNOFILE = lib.mkForce "65536:1048576";
  };
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
}
