{
  flake.modules.nixos.borg-server =
    { config, lib, pkgs, ... }:
    let
      # Generic per-host backup repos (modules/services/backup-client.nix).
      # Gated on the host's public key being present: a host without a
      # prepared borg keypair gets no repo entry yet (improvement session
      # 2026-11-12).
      backupHosts = [ "lenny" "rex" "zurg" "slinky" "buzz" ];
      backupRepos = builtins.listToAttrs (
        map
          (host: {
            name = host;
            value = {
              path = "/mnt/nas/borgbackup/${host}";
              quota = "50G";
              authorizedKeysAppendOnly = [
                (builtins.readFile (../../secrets/common/ssh + "/${host}/borg:${host}.pub"))
              ];
            };
          })
          (builtins.filter
            (host: builtins.pathExists (../../secrets/common/ssh + "/${host}/borg:${host}.pub"))
            backupHosts)
      );
    in
    {
      services.borgbackup.repos = {
        minetest = {
          path = "/mnt/nas/borgbackup/minetest";
          quota = "50G";
          authorizedKeysAppendOnly = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMHzhGXrb4GrFuRKi1bTdXcEz9J8vrGk/cn8KeDDlntI lnti"
          ];
        };
        minecraft-bedrock = {
          path = "/mnt/nas/borgbackup/minecraft-bedrock";
          quota = "50G";
          authorizedKeysAppendOnly = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM5Y64l29rfKiDBGrLDllN6rRzoDeMiyLCaoPN8LYpAH jessie"
          ];
        };
        pricklepants = {
          path = "/mnt/nas/borgbackup/pricklepants";
          quota = "50G";
          authorizedKeysAppendOnly = [
            (builtins.readFile (../../secrets/common/ssh + "/pricklepants/borg:pricklepants.pub"))
          ];
        };
        # nextcloud = {
        #   path = "/var/lib/borgbackup/nextcloud";
        #   authorizedKeysAppendOnly = [];
        # };
        # vaultwarden = {
        #   path = "/var/lib/borgbackup/vaultwarden";
        #   authorizedKeysAppendOnly = [];
        # };
      } // backupRepos;

      # nixpkgs generates one bootstrap unit per repo that mkdirs the repo path
      # and then chowns it. On the NAS rclone mount uid/gid are fixed by the
      # mount options (borg:borg), so chown returns EPERM — and a permanently
      # failed unit is not cosmetic: upgrade-health counts any failed unit as a
      # broken generation and rolls back (modules/system/upgrade-health.nix).
      # mkdir stays best-effort (the repos already exist, and new repo dirs are
      # provisioned before their client is enrolled); the real failure signal is
      # a borg job's onFailure alert.
      systemd.services =
        lib.mapAttrs' (
          name: repo:
          lib.nameValuePair "borgbackup-repo-${name}" {
            script = lib.mkForce ''
              ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg repo.path} 2>/dev/null || true
            '';
          }
        ) config.services.borgbackup.repos
        // {
          # Client keys are append-only (they can never delete), so retention
          # must run here as root. nixpkgs' borgbackup.jobs only prunes as part
          # of a backup (assertion requires paths/dumpCommand), which would
          # create junk archives just to satisfy its script — so this is a
          # direct service.
          #
          # No RequiresMountsFor on purpose: on the automounted NAS path a
          # failed mount would keep the unit from starting at all, so OnFailure
          # never fires. Accessing the path triggers the automount; if the NAS
          # is unreachable the glob stays literal and borg fails loudly.
          borg-prune = {
            description = "Prune + compact local borg repos (append-only clients cannot delete)";
            path = [ pkgs.borgbackup ];
            # Repos are owned by borg:borg; pruning/compacting as root leaves
            # root-owned index/segments behind, after which clients get EACCES.
            serviceConfig.User = "borg";
            serviceConfig.Group = "borg";
            script = ''
              set -euo pipefail
              for repo in /mnt/nas/borgbackup/*; do
                borg prune --verbose "$repo" --keep-within 90d --keep-daily 7 --keep-weekly 4
                borg compact "$repo"
              done
            '';
            # Prune failures used to be silent; page through the shared template.
            onFailure = lib.mkIf config.systemd.services."notify-telegram@".enable
              [ "notify-telegram@%i.service" ];
          };

          # Cloud copy of the backup tree: the NAS holds the local copy, Filen
          # the off-site one (decided 2026-11-12). rclone copy is incremental —
          # it skips unchanged segment files, so only new borg segments upload —
          # and deliberately never deletes: pruned segments stay in the cloud
          # copy, so a broken NAS/prune cannot propagate into the off-site copy.
          # (Growth is bounded by the repo quotas; `--backup-dir` versioning is
          # a later call.) Credentials: the filen service config already
          # deployed by the postgres-backup aspect (root reads the rendered
          # sops file). 05:30 leaves room after the weekly 03:30 prune/compact;
          # same no-RequiresMountsFor reasoning as borg-prune above.
          nas-filen-copy = {
            description = "Mirror the borg repo tree from the NAS to Filen";
            path = [ pkgs.rclone ];
            serviceConfig.Type = "oneshot";
            script = ''
              rclone copy /mnt/nas/borgbackup "filen:backup/nas-borgbackup" \
                --config ${config.sops.secrets."filen/postgres.conf".path} \
                --transfers 4 --create-empty-src-dirs --stats-one-line --log-level INFO
            '';
            onFailure = lib.mkIf config.systemd.services."notify-telegram@".enable
              [ "notify-telegram@%i.service" ];
          };
        };
      systemd.timers.borg-prune = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "Sun 03:30";
          Persistent = true;
        };
      };
      systemd.timers.nas-filen-copy = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "05:30";
          Persistent = true;
        };
      };
    };
}
