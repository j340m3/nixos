{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.upgradeHealth = {
    enable = lib.mkEnableOption "roll back the host when systemd reports failed units";

    settleDelay = lib.mkOption {
      type = lib.types.str;
      default = "5min";
      description = ''
        How long to wait after the check is triggered before judging the host.
        The trigger is either boot or a successful `nixos-upgrade.service`, so
        this is the only settle delay there is. Raise it on a host whose
        activation is slower than the default.
      '';
    };
  };

  # every host imports this module, so nothing at all is defined unless a host
  # opts in
  config = lib.mkIf config.upgradeHealth.enable {
    systemd.services.nixos-upgrade-health = {
      # boot window. multi-user.target wants this, so the check runs on every
      # boot: the same pattern NixOS's own activation unit uses. there is no
      # timer: a timer with `Unit = foo.service` activates foo.service when it
      # elapses, it does not wait for it, so it can never wait out the settle
      # delay in another unit.
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      # the one settle delay, covering both windows
      preStart = "${pkgs.coreutils}/bin/sleep ${config.upgradeHealth.settleDelay}";
      description = "Rolls the host back to the previous generation and reboots when systemd reports a failed unit. The guard file holds the failed-unit list of the last rollback, so one broken unit causes one rollback rather than one per hour.";
      script = ''
        guard=/var/lib/nixos-upgrade-health
        ${pkgs.coreutils}/bin/install -d -m 0755 "$guard"
        failed=$(${pkgs.systemd}/bin/systemctl --failed --plain --no-legend)
        # never act on our own past failure. a failed unit survives a
        # nixos-rebuild switch, so on a later good generation this service would
        # find itself listed and roll back a perfectly healthy host. the notify
        # units go too: a host without its telegram secrets fails them
        # permanently, and that alone is not a reason to roll back.
        # errors from this script stay in its own journal.
        # grep reads the whole list, so nothing here closes the pipe early, and
        # the `|| true` covers only grep exiting 1 with an empty result: a
        # failing systemctl above is still fatal under set -e.
        failed=$(printf '%s\n' "$failed" | ${pkgs.coreutils}/bin/grep -E -v '^(nixos-upgrade-health\.service|notify-telegram@[^ ]+) ' || true)
        if [ -z "$failed" ]; then
          # healthy: clear the guard, so a later unrelated failure can roll back
          # again instead of being mistaken for the one already handled
          ${pkgs.coreutils}/bin/rm -f "$guard/rolled-back-from"
          echo "upgrade-health: no failed units, nothing to do"
          exit 0
        fi
        # the unit name is the first word of the first line. expand it instead of
        # piping through head and cut: a pipeline that stops reading early can
        # raise SIGPIPE, and systemd.enableStrictShellChecks turns that into a
        # failed unit.
        nl='
        '
        first=''${failed%%"$nl"*}
        unit=''${first%% *}
        echo "upgrade-health: $unit failed"
        # notify before deciding, so the guard refusal below is reported too,
        # and never let a missing or failing notification block the rollback
        ${pkgs.systemd}/bin/systemctl start --no-block "notify-telegram@$unit.service" ||
          echo "upgrade-health: notification for $unit failed, continuing with the rollback"
        # the guard is keyed on the failure, not on the generation: an hourly
        # autoUpgrade mints a new profile link every time even when the store
        # path is unchanged, so a generation key never matches and the host
        # would roll back and reboot every hour for as long as the unit is
        # broken.
        if [ "$(${pkgs.coreutils}/bin/cat "$guard/rolled-back-from" 2>/dev/null || true)" = "$failed" ]; then
          echo "upgrade-health: already rolled back from this same set of failed units, not rolling back again"
          exit 1
        fi
        # record the failed units first, so a rollback that itself fails is not
        # retried on every trigger
        printf '%s\n' "$failed" > "$guard/rolled-back-from"
        ${pkgs.nixos-rebuild}/bin/nixos-rebuild rollback
        echo "upgrade-health: rolled back, rebooting"
        ${pkgs.systemd}/bin/systemctl reboot
      '';
    };

    # upgrade window. onSuccess is the native way to be activated when
    # nixos-upgrade.service succeeds, which covers `nixos-rebuild switch` and
    # the reboot it may schedule. running the check twice in one boot is
    # harmless: it is idempotent.
    systemd.services.nixos-upgrade.onSuccess = lib.mkIf config.system.autoUpgrade.enable [
      "nixos-upgrade-health.service"
    ];
  };
}
