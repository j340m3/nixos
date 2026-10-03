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
    };

    systemd.services.nixos-upgrade-health = {
      # no wantedBy: the timer is what starts this
      serviceConfig.Type = "oneshot";
      script = ''
        guard=/var/lib/nixos-upgrade-health
        ${pkgs.coreutils}/bin/install -d -m 0755 "$guard"
        failed=$(${pkgs.systemd}/bin/systemctl --failed --plain --no-legend)
        if [ -z "$failed" ]; then
          echo "upgrade-health: no failed units, nothing to do"
          exit 0
        fi
        unit=$(printf '%s\n' "$failed" | ${pkgs.coreutils}/bin/head -n 1 | ${pkgs.coreutils}/bin/cut -d' ' -f1)
        echo "upgrade-health: $unit failed, rolling back"
        ${pkgs.systemd}/bin/systemctl start --no-block "notify-telegram@$unit.service"
        generation=$(${pkgs.coreutils}/bin/readlink /nix/var/nix/profiles/system)
        if [ "$(cat "$guard/rolled-back-from" 2>/dev/null || true)" = "$generation" ]; then
          echo "upgrade-health: already rolled back from $generation, not rolling back again"
          exit 1
        fi
        printf '%s\n' "$generation" > "$guard/rolled-back-from"
        ${pkgs.nixos-rebuild}/bin/nixos-rebuild rollback
        ${pkgs.systemd}/bin/systemctl reboot
      '';
    };
  };
}
