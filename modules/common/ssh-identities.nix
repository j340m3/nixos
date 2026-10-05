{ config, lib, pkgs, constants, ... }:
{
  # Every peer host in the buildHosts inventory must ship a committed pub at
  # secrets/common/ssh/<host>/ssh.pub. Expected to FAIL right now: no pubs are
  # committed until T2 publishes them. The module still compiles green because
  # the hostKeys binding below is conditional on sops.secrets."ssh.key".
  assertions =
    let
      hosts = lib.attrNames constants.buildHosts;
    in
    map (h: {
      assertion = lib.pathExists (../../secrets/common/ssh + "/${h}/ssh.pub");
      message = "missing committed pub for ${h}";
    }) hosts;

  config = lib.mkMerge [
    {
      services.openssh.knownHosts =
        lib.mapAttrs (h: _: {
          publicKey = lib.fileContents (../../secrets/common/ssh + "/${h}/ssh.pub");
        }) constants.buildHosts;
    }
    # Only bind the LOCAL host's own key when this host has declared its sops
    # age secret (done in T4). Guarded so the module evals green before any
    # host declares sops.secrets."ssh.key".
    (lib.mkIf (config.sops.secrets ? "ssh.key") {
      security.ssh.hostKeys = [
        {
          type = "ed25519";
          path = config.sops.secrets."ssh.key".path;
        }
      ];
    })
  ];
}
