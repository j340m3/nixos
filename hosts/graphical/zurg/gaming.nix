{lib, pkgs, ...}:{
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia.modesetting.enable = true;
  #hardware.nvidia.open = true;
  #nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #           "nvidia-x11"
  #           "nvidia-settings"
  #         ];
  nixpkgs.config.allowUnfree = true;
  hardware.enableRedistributableFirmware = true;         
  programs.steam = {
    enable = true;
  };
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";
  #environment.systemPackages = [ (pkgs.writeShellScriptBin "reboot-kexec" (builtins.readFile ./reboot-kexec.sh)) ];
  programs.steam.gamescopeSession.enable = true;
  programs.gamemode.enable = true;
  environment.systemPackages = with pkgs; [mangohud protonup-qt lutris bottles heroic];
}
