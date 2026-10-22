# dendritic: aspect with absorbed body (was modules/_common/ssh-identities.nix).
{ inputs, ... }:
let
  constants = import (inputs.self + "/global/constants.nix");
in
{
  flake.modules.nixos.ssh-identities =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      hosts = lib.attrNames constants.buildHosts;
    in
    {
      config = lib.mkMerge [
        {
          assertions = map (h: {
            assertion = lib.pathExists (../../secrets/common/ssh + "/${h}/ssh.pub");
            message = "missing committed pub for ${h}";
          }) hosts;

          services.openssh.knownHosts = lib.mapAttrs (h: v: {
            hostNames = [
              h
              v.connect
            ];
            publicKey = lib.fileContents (../../secrets/common/ssh + "/${h}/ssh.pub");
          }) constants.buildHosts;
        }
        (lib.mkIf (config.sops.secrets ? "ssh.key") {
          services.openssh.hostKeys = [
            {
              type = "ed25519";
              path = config.sops.secrets."ssh.key".path;
            }
          ];
        })
      ];
    };
}
