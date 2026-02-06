{
  pkgs,
  inputs,
  config,
  ...
}:
{
  users.users.jeromeb = {
    isNormalUser = true;
    description = "Jerome";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;
  services.yubikey-agent.enable = true;
  services.udev.packages = [ pkgs.libfido2 ];
  # Install firefox.
  home-manager.backupFileExtension = "hmbackup";
  home-manager.users.jeromeb = import ../home;
  home-manager.extraSpecialArgs = { inherit inputs; };

  sops.secrets."filen/jeromeb.conf" = {
    format = "ini";
    sopsFile = ../secrets/users/jeromeb/rclone.ini;
    #restartUnits = ["nebula@mesh.service"];
    owner = "jeromeb";
    group = "users";
    #path = "/etc/nebula/self.key";
    key = "";
  };

  fileSystems."/mnt/filen/users/jeromeb" = {
    device = "filen:users/jerome";
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
      #"dir-cache-time=24h"
      #"vfs-cache-mode=full"
      #"vfs-cache-min-free-space=10G"
      #"vfs-fast-fingerprint"
      #"vfs-write-back=1m" # write changes after one hour
      #"vfs-cache-max-age=24h"                    # Retain cached files for up to 24 hours
      #"vfs-read-chunk-size=32M"                  # Start with 32MB chunks for faster initial reads
      #"vfs-read-chunk-size-limit=1G"             # Allow chunk size to grow up to 1GB for large files
      #"vfs-cache-poll-interval=30s"
      #"tpslimit=16"
      #"tpslimit-burst=32"
      "log-level=INFO"
      "log-file=/var/log/rclone/filen/jeromeb.log"
      "config=${config.sops.secrets."filen/jeromeb.conf".path}"
      "x-systemd.requires=network-online.target"
      "x-systemd.after=network-online.target" # only after network came up
      "uid=${config.users.users.jeromeb.uid}"
      #"gid=${config.users.users.jeromeb.group}"
    ];
  };
}
