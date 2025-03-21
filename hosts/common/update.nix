{ config, pkgs, inputs, lib,  ... }:

{
  options = {
    allowReboot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow random reboots.";
    };
  };
  
  config = {
    system.autoUpgrade = {
      enable = true;
      #flake = "/etc/nixos#nixos-gb";
      #flake = "github:j340m3/nixos#nixos-gb";
      flake = inputs.self.outPath;
      flags = [ 
      # "--update-input" "nixpkgs"
        "--update-all-inputs"
      #  "--no-write-lock-file"
      ];
      allowReboot = config.allowReboot;
      dates = "hourly";
      rebootWindow = {
        lower = "22:00";
        upper = "08:00";
      };
    };

    nix.gc = {
      automatic = true;
      dates = "hourly";
      options = "--delete-older-than 7d";
    };
    
    # Please do upgrades in Background
    nix = {
      package = pkgs.nix;
      settings.experimental-features = [ "nix-command" "flakes" ];
      settings.auto-optimise-store = true;
      settings.max-jobs = 1;
      settings.cores = 1;
      daemonIOSchedClass = lib.mkDefault "idle";
      daemonCPUSchedPolicy = lib.mkDefault "idle";
    };
    systemd.services.nix-daemon.serviceConfig.Slice = "-.slice";
    # always use the daemon, even executed  with root
    environment.variables.NIX_REMOTE = "daemon";
    systemd.services.nix-daemon.serviceConfig = {
      MemoryHigh = "800M";
      MemoryMax = "1G";
    };

    # Create an email notification service for failed jobs
    systemd.services."notify-telegram@" =
    {
        enable = true;
        environment.SERVICE_ID = "%i";
        script = ''
          TEMPFILE=$(mktemp)
          echo -e "\nGot an error with $SERVICE_ID\n\n" >> $TEMPFILE
          set +e
          systemctl status $SERVICE_ID >> $TEMPFILE
          set -e
          source /etc/telegram.secrets
          ${pkgs.curl}/bin/curl -s -X POST https://api.telegram.org/bot$BOT_TOKEN/sendMessage -d chat_id=$GROUP_ID -d text="$(cat $TEMPFILE)" > /dev/null
        '';
      };

    # Send an email whenever auto upgrade fails
    systemd.services.nixos-upgrade.onFailure =
      lib.mkIf config.systemd.services."notify-telegram@".enable
      [ "notify-telegram@%i.service" ];

  };
}
