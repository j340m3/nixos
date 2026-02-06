{ config, pkgs, lib, constants, ...} : 
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
  networking.firewall.interfaces."nebula.mesh".allowedTCPPorts = [ config.services.immich.port ];
  networking.firewall.allowedTCPPorts = [ config.services.immich.port ];
  services.nebula.networks.mesh.firewall.inbound = lib.mkIf 
              (config.services.immich.enable && 
              config.services.nebula.networks.mesh.enable) 
      [
        {
          cidr = constants.nebula.cidr;
          port = config.services.immich.port;
          proto = "any";
        }
      ];

  users.users.immich = {
    uid = 989;
    group = "immich";
    #home = "/mnt/nas/immich";
    #createHome = true;
  }; 
  
  fileSystems."/mnt/nas/immich" = {
    device = "immich:immich";
    fsType = "rclone";
    options = [
      "nodev"
      #"_netdev"
      #"nofail"
      "noauto"
      "allow_other"
      "args2env"
      "x-systemd.automount"
      "cache_dir=/var/cache/rclone"
      "dir-cache-time=24h"
      "sftp-path-override=/volume1/borgbackup/immich"
      "vfs-cache-mode=full"
      "vfs-cache-min-free-space=10G"
      "vfs-fast-fingerprint"
      "config=/etc/rclone-mnt.conf"
      "vfs-write-back=1m" # write changes after one hour
      "vfs-cache-max-age=24h"                    # Retain cached files for up to 24 hours
      "vfs-read-chunk-size=32M"                  # Start with 32MB chunks for faster initial reads
      "vfs-read-chunk-size-limit=1G"             # Allow chunk size to grow up to 1GB for large files
      "vfs-cache-poll-interval=30s" 
      #"tpslimit=8"
      #"tpslimit-burst=16"
      #"bwlimit=1K"
      #"transfers=4"
      "log-level=INFO"
      "log-file=/var/log/rclone.log"
      "x-systemd.requires=network-online.target"
      "x-systemd.after=network-online.target" # only after network came up
      "uid=${toString config.users.users.immich.uid}"
      "gid=${config.users.users.immich.group}"
    ];
  };

  systemd.services."immich-server.service".after = ["mnt-nas-immich.mount"];
}
