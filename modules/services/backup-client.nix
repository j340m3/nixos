# Auto-homes borg client (improvement session 2026-11-12): one generic
# daily job per host backing up every real user's home — auto-discovered
# from users.users, with donquezz excluded (unprivileged admin alias, see
# the privilege-model decision) — plus whatever application paths the
# feature modules contribute via options.backup.paths (carrier:
# modules/nix/backup.nix). Application-wise paths, not a blind /etc.
#
# Prerequisite to import this aspect on a host: a borg ssh keypair —
# private key as borg/<host> in secrets/hosts/<host>/secrets.yaml, public
# key as secrets/common/ssh/<host>/borg:<host>.pub (feeds woody's
# append-only repo authorization, modules/services/borg-server.nix).
let
  constants = import ../global/_constants.nix;
in
{
  inputs,
  lib,
  ...
}:
{
  flake.modules.nixos.backup-client = { config, ... }: {
    imports = [
      (inputs.self.lib.borgClientJob {
        name = "backup";
        secretKey = "borg/${config.networking.hostName}";
        secretFile = ../../secrets/hosts/${config.networking.hostName}/secrets.yaml;
        paths =
          lib.mapAttrsToList
            (name: user: user.home or "/home/${name}")
            (lib.filterAttrs
              (name: user: (user.isNormalUser or false) && name != "donquezz")
              config.users.users)
          ++ config.backup.paths;
        repo = "borg@${constants.host.woody.ip}:${config.networking.hostName}";
      })
    ];
  };
}
