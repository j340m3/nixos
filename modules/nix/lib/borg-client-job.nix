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
    { config, pkgs, ... }:
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

      # RNS path warm-up before borg dials the bridge: an rnsh client whose
      # RNS.Link starts while the path table has no route to the destination
      # hangs forever (it never retries once the path arrives later) - seen
      # 2026-11-12 on pricklepants (20+ min pre-start probe, manual probe
      # linked instantly once rnpath confirmed the 2-hop route). rnpath
      # against the shared instance requests and waits for the route; the
      # timeout keeps a dead mesh from stalling the unit forever. Repo
      # strings for the nebula fallback (IP-based) skip this entirely.
      systemd.services."borgbackup-job-${name}" = {
        # RNS path warm-up before borg dials the bridge: an rnsh client whose
        # RNS.Link starts while the path table has no route to the destination
        # hangs forever (it never retries once the path arrives later) - seen
        # 2026-11-12 on pricklepants (20+ min pre-start probe, manual probe
        # linked instantly once rnpath confirmed the 2-hop route). rnpath
        # against the shared instance requests and waits for the route; the
        # timeout keeps a dead mesh from stalling the unit forever. Repo
        # strings for the nebula fallback (IP-based) skip this entirely.
        preStart =
          let
            hostMatch = builtins.match "[^@]*@([^:]*):.*" repo;
            bridgeHost = if hostMatch != null then builtins.elemAt hostMatch 0 else "";
          in
          lib.mkIf (lib.hasSuffix "-rns" bridgeHost) ''
            dest=""
            # bash builtins only: the job unit PATH carries borg + openssh,
            # not coreutils/awk (pricklepants 2026-11-12: bare awk -> 127)
            while read -r name hash; do
              if [ "$name" = "${bridgeHost}" ]; then dest="$hash"; break; fi
            done < /etc/reticulum/ssh-hosts
            if [ -n "$dest" ]; then
              echo "warming RNS path to $dest for ${bridgeHost}"
              ${pkgs.coreutils}/bin/timeout 300 ${
                pkgs.python3Packages.rns
              }/bin/rnpath "$dest" --config /var/lib/reticulum || true
            fi
          '';

        onFailure =
          lib.mkIf config.systemd.services."notify-telegram@".enable
            [ "notify-telegram@%i.service" ];
      };
    };
}
