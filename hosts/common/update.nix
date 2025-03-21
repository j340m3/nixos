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
        "--update-input" "nixpkgs" 
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
    systemd.services."notify-email@" =
      let address = "system@kauderwels.ch";
      in {
        enable = true;
        environment.SERVICE_ID = "%i";
        script = ''
          TEMPFILE=$(mktemp)
          echo "From: ${address}" > $TEMPFILE
          echo "To: ${address}" >> $TEMPFILE
          echo "Subject: Failure in $SERVICE_ID" >> $TEMPFILE
          echo -e "\nGot an error with $SERVICE_ID\n\n" >> $TEMPFILE
          set +e
          systemctl status $SERVICE_ID >> $TEMPFILE
          set -e
          ${pkgs.msmtp}/bin/msmtp \
              --file=${config.homePath}/.config/msmtp/config \
              --account=system \
              ${address} < $TEMPFILE
        '';
      };

    # Send an email whenever auto upgrade fails
    systemd.services.nixos-upgrade.onFailure =
      lib.mkIf config.systemd.services."notify-email@".enable
      [ "notify-email@%i.service" ];

  };
}
