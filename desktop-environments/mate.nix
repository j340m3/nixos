{ config, pkgs, lib, ...} : {
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.mate.enable = true;

  # Automatic Display resize
  services.spice-vdagentd.enable = true;
}