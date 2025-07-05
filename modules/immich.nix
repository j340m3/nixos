{ config, pkgs, lib, ...} : 
{
  services.immich.enable = true;
  services.immich.port = 2283;
  services.immich.accelerationDevices = null;

/* hardware.graphics = { 
 # ...
 # See: https://wiki.nixos.org/wiki/Accelerated_Video_Playback
}; */

  users.users.immich.extraGroups = [ "video" "render" ];
}