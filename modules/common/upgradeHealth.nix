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
        The wait between `switch-to-configuration.service` becoming active and
        judging the host. Raise it on a host whose activation is slower than
        the default.
      '';
    };
  };

  # every host imports this module, so nothing at all is defined unless a host
  # opts in
  config = lib.mkIf config.upgradeHealth.enable {
    systemd.timers.nixos-upgrade-health = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        Unit = "switch-to-configuration.service";
        OnUnitActiveSec = config.upgradeHealth.settleDelay;
        AccuracySec = "1min";
        Persistent = false;
      };
      description = "Runs the upgrade health check one settle delay after switch-to-configuration.service goes active, which covers both a boot and a nixos-rebuild switch.";
    };

    systemd.services.nixos-upgrade-health = {
      # no wantedBy: the timer is what starts this
      serviceConfig.Type = "oneshot";
      description = "Rolls the host back to the previous generation and reboots when systemd reports a failed unit. A host already sitting on its fallback generation refuses, so one broken unit cannot make it roll back generation after generation.";
      script = ''
        guard=/var/lib/nixos-upgrade-health
        ${pkgs.coreutils}/bin/install -d -m 0755 "$guard"
        failed=$(${pkgs.systemd}/bin/systemctl --failed --plain --no-legend)
        # never act on our own past failure. a failed unit survives a
        # nixos-rebuild switch, so on a later good generation this service would
        # find itself listed and roll back a perfectly healthy host. errors from
        # this script stay in its own journal.
        # grep reads the whole list, so nothing here closes the pipe early, and
        # the `|| true` covers only grep exiting 1 with an empty result: a
        # failing systemctl above is still fatal under set -e.
        failed=$(printf '%s\n' "$failed" | ${pkgs.coreutils}/bin/grep -v '^nixos-upgrade-health\.service ' || true)
        if [ -z "$failed" ]; then
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
        generation=$(${pkgs.coreutils}/bin/readlink /nix/var/nix/profiles/system)
        if [ "$(${pkgs.coreutils}/bin/cat "$guard/rolled-back-from" 2>/dev/null || true)" = "$generation" ]; then
          echo "upgrade-health: already rolled back from $generation, not rolling back again"
          exit 1
        fi
        # record the attempt first, so a rollback that itself fails is not
        # retried every settle delay
        printf '%s\n' "$generation" > "$guard/rolled-back-from"
        ${pkgs.nixos-rebuild}/bin/nixos-rebuild rollback
        # then record the generation we now sit on. a host on its fallback
        # generation therefore refuses, which is what stops the cascade when
        # the failed unit was already broken before the upgrade and a rollback
        # cannot fix it.
        fallback=$(${pkgs.coreutils}/bin/readlink /nix/var/nix/profiles/system)
        printf '%s\n' "$fallback" > "$guard/rolled-back-from"
        echo "upgrade-health: rolled back to $fallback, rebooting"
        ${pkgs.systemd}/bin/systemctl reboot
      '';
    };
  };
}
