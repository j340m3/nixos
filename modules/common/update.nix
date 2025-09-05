{ config, pkgs, inputs, lib,  ... }:

{
  imports = [
      #inputs.lix-module.nixosModules.default
      inputs.comin.nixosModules.comin
    ];

  options = {
    allowReboot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow random reboots.";
    };
    useComin = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Comin.";
    };
  };
  
  config = {
    services.nebula.networks.mesh.firewall.inbound = lib.mkIf 
              (config.services.comin.enable && 
              config.services.nebula.networks.mesh.enable) 
      [
        {
          cidr = constants.nebula.cidr;
          port = "4242";
          proto = "any";
        }
      ];
    
    services.comin = {
      enable = config.useComin;
      remotes = [
        {
          name = "origin";
          url = "https://github.com/j340m3/nixos.git";
          # This is an access token to access our private repository
          # auth.access_token_path = cfg.sops.secrets."gitlab/access_token".path;
          # No testing branch on this remote
          branches.testing.name = "";
        }
      ];
      #machineId = "22823ba6c96947e78b006c51a56fd89c";
    };
    system.autoUpgrade = {
      enable = !config.useComin;
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
      #package = pkgs.lix;
      settings = {
        substituters = [ "https://cache.kauderwels.ch:5000" "https://nix-community.cachix.org" "https://cache.nixos.org"];
        trusted-public-keys = [ "cache.kauderwels.ch:0fswEglSoELjSBSMOuvnLAXMstePxzeTmOTYziR7z+Y=" "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="];
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
    #systemd.services.nix-daemon.serviceConfig.Slice = "-.slice";
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

    nix.settings.max-silent-time = let minute = 60; in 120 * minute;
   /*  services.earlyoom = {
      enable = true;
      enableNotifications = true;
      extraArgs =
        let
          catPatterns = patterns: builtins.concatStringsSep "|" patterns;
          preferPatterns = [
            ".firefox-wrappe"
            "minetest"
            "vaultwarden"
            "java" # If it's written in java it's uninmportant enough it's ok to kill it
          ];
          avoidPatterns = [
            "bash"
            "mosh-server"
            "sshd"
            "systemd"
            "systemd-logind"
            "systemd-udevd"
            "tmux: client"
            "tmux: server"
            "nix"
            "nebula"
          ];
        in
        [
          "--prefer" "'^(${catPatterns preferPatterns})$'"
          "--avoid" "'^(${catPatterns avoidPatterns})$'"
        ];
    }; */
    

    systemd.slices.anti-hungry.sliceConfig = {
      CPUAccounting = true;
      CPUQuota = "50%";
      MemoryAccounting = true; # Allow to control with systemd-cgtop
      MemoryHigh = "50%";
      MemoryMax = "75%";
      MemorySwapMax = "50%";
      MemoryZSwapMax = "50%";
    };

    systemd.services.nix-daemon.serviceConfig.Slice = "anti-hungry.slice";

    # Avoid freezing the system
    /* systemd.oomd.enable = true;
    systemd.oomd.enableRootSlice = true;
    systemd.oomd.enableSystemSlice = true;
    systemd.oomd.enableUserSlices = true; */
    zramSwap.enable = true;

  };
}
