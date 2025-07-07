{ config, pkgs, lib, ...} : 
{
  services.immich.enable = true;
  services.immich.port = 2283;
  services.immich.accelerationDevices = null;
  services.immich.host = "0.0.0.0";

/* hardware.graphics = { 
 # ...
 # See: https://wiki.nixos.org/wiki/Accelerated_Video_Playback
}; */

  users.users.immich.extraGroups = [ "video" "render" ];
  networking.firewall.interfaces.mesh.allowedTCPPorts = [ 2283 ];
}