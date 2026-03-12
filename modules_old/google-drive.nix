{
  config,
  lib,
  pkgs,
  ...
} : { 
  environment.systemPackages = [ pkgs.rclone ];
  # environment.etc."rclone-mnt.conf".text = ''
  #   [myremote]
  #   type = sftp
  #   host = 192.0.2.2
  #   user = myuser
  #   key_file = /root/.ssh/id_rsa
  # '';

  # fileSystems."/mnt" = {
  #   device = "myremote:/my_data";
  #   fsType = "rclone";
  #   options = [
  #     "nodev"
  #     "nofail"
  #     "allow_other"
  #     "args2env"
  #     "config=/etc/rclone-mnt.conf"
  #   ];
  # };
}