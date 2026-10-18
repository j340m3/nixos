{
  config,
  lib,
  pkgs,
  ...
}:
{
  services.borgbackup.repos = {
    matrix = {
      path = "/var/lib/borgbackup/matrix";
      authorizedKeysAppendOnly = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFuaGVhBlZ1yTk4NfbQwRTkFYcL4H86wbx2NJH4oMtRx mtrx"
      ];
    };
    minetest = {
      path = "/var/lib/borgbackup/minetest";
      authorizedKeysAppendOnly = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMHzhGXrb4GrFuRKi1bTdXcEz9J8vrGk/cn8KeDDlntI lnti"
      ];
    };
    minecraft-bedrock = {
      path = "/var/lib/borgbackup/minecraft-bedrock";
      authorizedKeysAppendOnly = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM5Y64l29rfKiDBGrLDllN6rRzoDeMiyLCaoPN8LYpAH jessie"
      ];
    };
    pricklepants = {
      path = "/var/lib/borgbackup/pricklepants";
      authorizedKeysAppendOnly = [
        (builtins.readFile (../secrets/common/ssh + "/pricklepants/borg:pricklepants.pub"))
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
  };

  # Client keys are append-only (they can never delete), so retention must
  # run here as root. nixpkgs' borgbackup.jobs only prunes as part of a
  # backup (assertion requires paths/dumpCommand), which would create junk
  # archives just to satisfy its script — so this is a direct service.
  systemd.services.borg-prune = {
    description = "Prune + compact local borg repos (append-only clients cannot delete)";
    path = [ pkgs.borgbackup ];
    script = ''
      set -euo pipefail
      for repo in /var/lib/borgbackup/*; do
        borg prune --verbose "$repo" --keep-within 90d --keep-daily 7 --keep-weekly 4
        borg compact "$repo"
      done
    '';
  };
  systemd.timers.borg-prune = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun 03:30";
      Persistent = true;
    };
  };
}
