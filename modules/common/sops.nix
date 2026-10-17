{
  config,
  pkgs,
  lib,
  ...
}:
{
  sops.defaultSopsFile = ../../secrets/shared.yaml;
  #sops.age.generateKey = true;
}
