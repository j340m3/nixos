{ config, lib, pkgs, constants, ... }:
let
  hosts = lib.attrNames constants.buildHosts;
in
{
  config = lib.mkMerge [
    {
      assertions =
        map (h: {
          assertion = lib.pathExists (../../secrets/common/ssh + "/${h}/ssh.pub");
          message = "missing committed pub for ${h}";
        }) hosts;

      services.openssh.knownHosts =
        lib.mapAttrs (h: v: {
          hostNames = [ h v.connect ]
            ++ (lib.optional ((constants.host.${h}.ygg or null) != null)
                  constants.host.${h}.ygg);
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
}
