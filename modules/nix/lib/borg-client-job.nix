# Borg client backup job: one sops secret + one borgbackup job pushing to
# woody's borg-server, plus the telegram notification on failure. Every job
# in the fleet shares this skeleton (commits 4b313c9/1de1d60 pattern):
#
#   imports = [ (inputs.self.lib.borgClientJob {
#     name = "minetest";                # job + repo + unit suffix
#     paths = "/var/lib/minetest/.minetest";
#     repo = "borg@${constants.host.woody.ip}:.";
#     secretFile = ../../secrets/hosts/.../secrets.yaml;
#     secretKey ? "borg/${name}",       # minetest's key is borg/luanti
#     startAt ? "daily",                # bedrock runs a fixed timer
#     tolerateRepoDrift ? true,         # pp's RNS-bridge repo skips the vars
#     borgRsh ? null,                   # override; pp pins the -rns shim path
#     extra ? { },                      # preHook/postHook passthrough
#   }) ];
#
# BORG_RSH always carries the key and -p constants.sshPort: the loghost's
# endlessh owns port 22, the real sshd answers on the hardened port (2026-11-03
# log sweep). The tolerate vars exist because borg runs non-interactively: a
# dropped client security cache (or a recreated repo) aborts the job with
# "Attempting to access a previously unknown unencrypted repository!" — these
# are family LAN backups over the mesh, so accept and resume automatically.
{ inputs, lib, ... }:
let
  constants = import ../../global/_constants.nix;
in
{
  flake.lib.borgClientJob =
    {
      name,
      paths,
      repo,
      secretFile,
      secretKey ? "borg/${name}",
      startAt ? "daily",
      tolerateRepoDrift ? true,
      borgRsh ? null,
      extra ? { },
    }:
    { config, ... }:
    {
      sops.secrets.${secretKey} = {
        sopsFile = secretFile;
      };

      services.borgbackup.jobs.${name} = {
        inherit paths;
        encryption.mode = "none";
        environment = {
          BORG_RSH =
            if borgRsh != null then
              borgRsh
            else
              "ssh -i ${config.sops.secrets.${secretKey}.path} -p ${
                toString constants.sshPort
              }";
        }
        // lib.optionalAttrs tolerateRepoDrift {
          BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK = "yes";
          BORG_RELOCATED_REPO_ACCESS_IS_OK = "yes";
        };
        inherit repo;
        compression = "auto,lzma";
        inherit startAt;
      } // extra;

      systemd.services."borgbackup-job-${name}".onFailure =
        lib.mkIf config.systemd.services."notify-telegram@".enable
          [ "notify-telegram@%i.service" ];
    };
}
