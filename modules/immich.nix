{ config, pkgs, lib, ...} : 
{
  environment.systemPackages = with pkgs; [
		immich-machine-learning
	];
  services = {
    immich = {
      enable = true;
      host = "::";
      #secretsFile = config.vaultix.secrets.immich.path;
      database.createDB = true;
      machine-learning.enable = true;
      redis.enable = true;
      settings = null;
      accelerationDevices = null;
      port = 2283;
      # mediaLocation = "/mnt/nas/immich";
    };
  };

/* hardware.graphics = { 
 # ...
 # See: https://wiki.nixos.org/wiki/Accelerated_Video_Playback
}; */

  users.users.immich.extraGroups = [ "video" "render" ];
  networking.firewall.interfaces."nebula.mesh".allowedTCPPorts = [ 2283 ];
  networking.firewall.allowedTCPPorts = [ 2283 ];

  users.users.immich = {
    home = "/var/lib/immich";
    createHome = true;
  };
}