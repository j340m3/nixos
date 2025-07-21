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
      /* settings = {
        logging = {
          enabled = true;
          level = "verbose";
        };
      }; */
      accelerationDevices = null;
      port = 2283;
      mediaLocation = "/mnt/nas/immich";
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
    uid = 989;
    group = "immich";
    #home = "/mnt/nas/immich";
    #createHome = true;
  }; 
  fileSystems."/mnt/nas/immich" = {
    device = "immich:/immich";
    fsType = "rclone";
    options = [
      "nodev"
      "_netdev"
      "nofail"
      "noauto"
      "allow_other"
      "args2env"
      "x-systemd.automount"
      "cache_dir=/var/cache/rclone"
      "dir-cache-time=24h"
      "poll-interval=1h"
      "vfs-cache-mode=full"
      "vfs-cache-min-free-space=10G"
      "vfs-fast-fingerprint"
      "config=/etc/rclone-mnt.conf"
      "vfs-write-back=1h" # write changes after one hour
      "tpslimit=8"
      "tpslimit-burst=16"
      "x-systemd.after=network-online.target" # only after network came up
      "uid=${toString config.users.users.immich.uid}"
      "gid=${config.users.users.immich.group}"
    ];
  };

  systemd.services."immich-server.service".after = ["mnt-nas-immich.mount"];
}