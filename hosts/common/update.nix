{ config, pkgs, inputs, lib,  ... }:

{
  options = {
    allowReboot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow random reboots.";
    };
  };
  
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
  };

  nix.gc = {
    automatic = true;
    dates = "hourly";
    options = "--delete-older-than 1d";
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

}