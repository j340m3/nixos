{
  config,
  constants,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # Membership follows the host dirs under modules/hosts: adding a host
  # dir enrolls it.
  members = builtins.attrNames (builtins.readDir ../../modules/hosts);

  # One ping check per mesh-roster host with a verified nebula ip; hosts
  # without one (pending the ygg harvest) are skipped.
  checks = lib.mapAttrsToList (_: h: {
    type = "ping";
    target = h.ip;
  }) (lib.filterAttrs (_: h: h ? ip) constants.host);
in
{
  imports = [ inputs.peerpatrol.nixosModules.default ];

  # ponytail: upstream package is x86_64-only; slinky (aarch64) must not
  # inherit a binary it cannot exec. Add packages.aarch64-linux upstream,
  # then key the package on pkgs.system instead of gating.
  services.peerpatrol = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 {
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

  # The daemon writes monitor-state.txt relative to its cwd.  Without this
  # it lands in /, which DynamicUser makes read-only (ProtectSystem=strict),
  # and peerpatrol exits with "state path ... not writable".
  systemd.services.peerpatrol.serviceConfig.WorkingDirectory = "/var/lib/peerpatrol";
}
