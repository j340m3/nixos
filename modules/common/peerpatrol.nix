{
  config,
  constants,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # Membership follows the host dirs: adding a host dir enrolls it.
  members =
    builtins.attrNames (builtins.readDir ../../hosts/graphical)
    ++ builtins.attrNames (builtins.readDir ../../hosts/headless);

  # One ping check per mesh-roster host with a verified nebula ip; hosts
  # without one (pending the ygg harvest) are skipped.
  checks = lib.mapAttrsToList (_: h: {
    type = "ping";
    target = h.ip;
  }) (lib.filterAttrs (_: h: h ? ip) constants.host);
in
{
  imports = [ inputs.peerpatrol.nixosModules.default ];

  services.peerpatrol = {
    enable = true;
    package = inputs.peerpatrol.packages.x86_64-linux.default;
    # Placeholders in the shared JSON; real values arrive via the
    # sops-decrypted files passed through systemd LoadCredential.
    configFile = pkgs.writers.writeJSON "peerpatrol-config.json" {
      telegram.bot_token = "sops-override";
      telegram.chat_id = 0;
      inherit members;
      inherit checks;
    };
    tokenFile = config.sops.secrets."telegram/bot_token".path;
    chatIdFile = config.sops.secrets."telegram/group_id".path;
  };
}
