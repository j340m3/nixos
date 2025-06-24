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
      flake = "github:j340m3/nixos";
      #flake = inputs.self.outPath;
      flags = [ 
      # "--update-input" "nixpkgs"
      # "--update-all-inputs"
        "--no-write-lock-file"
      ];
      allowReboot = config.allowReboot;
      dates = lib.mkDefault "*-*-* 0/1:45:00";
      randomizedDelaySec = lib.mkDefault "25min";
      #dates = lib.mkDefault "hourly";
      rebootWindow = {
        lower = lib.mkDefault "22:00";
        upper = "08:00";
      };
    };

    nix.gc = {
      automatic = true;
      dates = lib.mkDefault "*-*-* 0/1:15:00";
      randomizedDelaySec = lib.mkDefault "25min";
      options = lib.mkDefault "--delete-older-than 7d";
    };
    
    # Please do upgrades in Background
    nix = {
      package = pkgs.nix;
      settings = {
        experimental-features = [ "nix-command" "flakes" ];
        auto-optimise-store = true;
        max-jobs = lib.mkDefault 1;
        cores = lib.mkDefault 1;
        min-free = lib.mkDefault "${toString (100 * 1024 * 1024)}";
        max-free = lib.mkDefault "${toString (1024 * 1024 * 1024)}";
      };

      daemonIOSchedClass = lib.mkDefault "idle";
      daemonCPUSchedPolicy = lib.mkDefault "idle";
    };
    systemd.services.nix-daemon.serviceConfig.Slice = "-.slice";
    # always use the daemon, even executed  with root
    environment.variables.NIX_REMOTE = "daemon";
    systemd.services.nix-daemon.serviceConfig = {
      MemoryHigh = lib.mkDefault "800M";
      MemoryMax = lib.mkDefault "1G";
    };

    # TODO: Change to Sops-nix secrets
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
          export GROUP_ID="$(cat ${config.sops.secrets."telegram/group_id".path})"
          export BOT_TOKEN="$(cat ${config.sops.secrets."telegram/bot_token".path})"
          ${pkgs.curl}/bin/curl -s -X POST https://api.telegram.org/bot$BOT_TOKEN/sendMessage -d chat_id=$GROUP_ID -d text="${config.networking.hostName}: $(cat $TEMPFILE)" > /dev/null
        '';
      };

    sops.secrets."telegram/group_id" = {};
    sops.secrets."telegram/bot_token" = {};

    # Send an email whenever auto upgrade fails
    systemd.services.nixos-upgrade.onFailure =
      lib.mkIf config.systemd.services."notify-telegram@".enable
      [ "notify-telegram@%i.service" ];

  };
}
