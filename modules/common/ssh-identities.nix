{ config, lib, pkgs, constants, ... }:
let
  hosts = lib.attrNames constants.buildHosts;
in
{
  config = {
    assertions =
      map (h: {
        assertion = lib.pathExists (../../secrets/common/ssh + "/${h}/ssh.pub");
        message = "missing committed pub for ${h}";
      }) hosts;

    services.openssh.knownHosts =
      lib.mapAttrs (h: _: {
        publicKey = lib.fileContents (../../secrets/common/ssh + "/${h}/ssh.pub");
      }) constants.buildHosts;
  };
}
