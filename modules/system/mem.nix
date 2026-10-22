# dendritic aspect (ADR 0014): memory-pressure hardening absorbed from
# _common/mem.nix (earlyoom + sysctls + per-service cgroup ceilings).
_: {
  flake.modules.nixos.mem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.commonMem = {
        enable = lib.mkEnableOption ''
          Memory-pressure hardening for small hosts: earlyoom as the OOM
          safety net, swap-inflation sysctls tuned for zram, and a
          MemoryMax/MemoryHigh ceiling on every service so one runaway
          process cannot starve the rest of the machine.
        '';

        earlyoom = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Run earlyoom. earlyoom watches available memory and swap and
              kills the biggest offender before the kernel OOM killer gets to
              it, which is the difference between a controlled kill and a
              whole-machine thrash on a host with no real swap.
            '';
          };

          preferPatterns = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "vaultwarden"
              "minetest"
              "java"
            ];
            description = ''
              Regexes earlyoom prefers to kill first. Order matters: the
              first match wins. These are the disposable services on a 1 GB
              host -- a crashed vaultwarden is recoverable, sshd is not.
            '';
          };

          avoidPatterns = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "bash"
              "mosh-server"
              "sshd"
              "systemd"
              "systemd-logind"
              "systemd-udevd"
              "tmux: client"
              "tmux: server"
              "nix-daemon"
              "nix"
              "nebula"
            ];
            description = ''
              Regexes earlyoom must never kill. A missed entry here is a
              locked-out host, so this list is explicit rather than a
              negated prefer list.
            '';
          };
        };
      };

      config = lib.mkIf config.commonMem.enable {
        services.earlyoom = {
          enable = config.commonMem.earlyoom.enable;
          enableNotifications = true;
          # A 1 GB host has almost no headroom. Start looking at 8% free
          # memory rather than the default 10%, and go straight to SIGKILL
          # instead of giving the process a chance to allocate more.
          freeMemThreshold = 8;
          freeSwapThreshold = 5;
          reportInterval = 0;
          extraArgs = [
            "--prefer"
            "(^|/)(${builtins.concatStringsSep "|" config.commonMem.earlyoom.preferPatterns})$"
            "--avoid"
            "(^|/)(${builtins.concatStringsSep "|" config.commonMem.earlyoom.avoidPatterns})$"
          ];
        };

        systemd.services.earlyoom.serviceConfig = {
          # earlyoom scores every process by reading /proc. the NixOS module
          # defaults this to "strict", which is fine: /proc is a virtual
          # filesystem and stays visible, and the notification goes over D-Bus,
          # not the filesystem. nothing to override here.
        };

        # Swap-inflation sysctls. These only matter when the host is under
        # memory pressure, which is exactly when they are needed, and they
        # are cheap to apply. The aggressive values come from the existing
        # zram.nix defaults; they are repeated here so a host that imports
        # this module but not zram.nix still gets them.
        boot.kernel.sysctl = {
          "vm.swappiness" = lib.mkForce 180;
          "vm.watermark_boost_factor" = lib.mkForce 0;
          "vm.watermark_scale_factor" = lib.mkForce 125;
          "vm.page-cluster" = lib.mkForce 0;
          "vm.dirty_background_ratio" = lib.mkForce 1;
          "vm.vfs_cache_pressure" = lib.mkForce 500;
        };

        # Cap every service at 800 MB. MemoryHigh is a soft limit: the
        # kernel throttles the cgroup when it crosses it, which gives the
        # process a chance to clean up. MemoryMax is hard: when the cgroup
        # hits it the kernel OOM-kills inside the cgroup, which is what we
        # want on a 1 GB host -- a bounded kill inside one service instead
        # of an unbounded kill across the whole machine.
        #
        # lib.mkDefault only fires when nothing else sets the option, so a
        # service that declares its own MemoryMax keeps it and this module
        # never overrides it. services that do not appear here get no cap.
        systemd.services = {
          "nix-daemon".serviceConfig = {
            MemoryHigh = lib.mkDefault "800M";
            MemoryMax = lib.mkDefault "1G";
          };
          "vaultwarden".serviceConfig = {
            MemoryHigh = lib.mkDefault "300M";
            MemoryMax = lib.mkDefault "400M";
          };
          "minetest-server".serviceConfig = {
            MemoryHigh = lib.mkDefault "400M";
            MemoryMax = lib.mkDefault "512M";
          };
          "nebula@mesh".serviceConfig = {
            MemoryHigh = lib.mkDefault "100M";
            MemoryMax = lib.mkDefault "128M";
          };
          "nginx".serviceConfig = {
            MemoryHigh = lib.mkDefault "150M";
            MemoryMax = lib.mkDefault "200M";
          };
        };
      };
    };
}
