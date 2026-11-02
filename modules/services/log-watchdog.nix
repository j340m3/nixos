{ inputs, ... }:
let
  constants = import ../global/_constants.nix;
in
{
  flake.modules.nixos.log-watchdog =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # Roster hosts whose silence is expected because they are off /
      # not updated yet (2026-11-02 log sweep decision): their last real
      # writes are 2025-08/09, the machine themselves need no ping. Flip
      # them to monitored (delete from this list) when they are brought
      # back or updated.
      expectedOff = [
        "lenny"
        "rex"
        "slinky"
        "buzz"
      ];
      logDir = "/persist/rsyslog";
      maxAge = 48 * 60 * 60; # 48h staleness threshold
      monitored = lib.filter (h: !(builtins.elem h expectedOff)) (builtins.attrNames constants.host);
    in
    {
      # The 2026-11-02 log sweep turned up hosts that silently stopped
      # forwarding (cheap-lease teardown, disk queue gone dark) with nobody
      # noticing for months. Periodically compare the newest log file
      # mtime in ${logDir}/<host> (written live by rsyslog on the loghost)
      # against the threshold; alert once per found gap over the fleet's
      # telegram bot (same sops secrets the notify-telegram@ template
      # uses). Quiet while everything is fresh.
      systemd.services.log-watchdog = {
        description = "Alert when roster hosts stop shipping logs";
        after = [ "sops-nix.service" ];
        requires = [ "sops-nix.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "log-watchdog" ''
            set -uo pipefail
            now=$(date +%s)
            max=${toString maxAge}
            report=""
            for h in ${lib.concatMapStringsSep " " lib.escapeShellArg monitored}; do
              latest=$(find "${logDir}/$h" -maxdepth 1 -name '*.log' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f1)
              if [ -z "$latest" ]; then
                report="''${report}  $h: no .log files on the loghost\\n"
                continue
              fi
              latest=''${latest%%.*}
              age=$((now - latest))
              if [ "$age" -gt "$max" ]; then
                report="''${report}  $h: newest log $((age / 3600))h old (>$((max / 3600))h)\\n"
              fi
            done
            if [ -n "$report" ]; then
              printf -v msg 'fleet-log-watchdog: hosts silent >%sh\\n%s' "$((max / 3600))" "$report"
              ${pkgs.curl}/bin/curl -fsS -X POST ${"https://api.telegram.org/bot$(cat ${config.sops.secrets."telegram/bot_token".path})/sendMessage"} --data-urlencode "chat_id=$(cat ${
                config.sops.secrets."telegram/group_id".path
              })" --data-urlencode "text=$msg" ||
                echo "log-watchdog: telegram send failed"
            fi
          '';
        };
      };

      systemd.timers.log-watchdog = {
        timerConfig = {
          Unit = "log-watchdog.service";
          OnCalendar = "daily";
          RandomizedDelaySec = "15m";
        };
        wantedBy = [ "timers.target" ];
      };
    };
}
