{ config, pkgs, lib, ...} : {
  environment.systemPackages = with pkgs; [
    #wezterm
    #tmux
  ];
}
