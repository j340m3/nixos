{
  config,
  ...
}:
{
  # For mount.cifs, required unless domain name resolution is not needed.
  # environment.systemPackages = [ pkgs.cifs-utils ];
  fileSystems."/mnt/share" = {
    device = "//bergmannnas/home";
    fsType = "cifs";
    options =
      let
        # this line prevents hanging on network split
        automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";

      in
      [
        "${automount_opts},credentials=/etc/nixos/smb-secrets,uid=${toString config.users.users.jeromeb.uid},gid=${toString config.users.groups.users.gid}"
      ];
  };
  services.gvfs.enable = true;

  environment.etc."rclone-mnt.conf" = {
    text = ''
      [immich]
      type = sftp
      host = bergmannnas.fritz.box
      user = borg
      key_file = /root/.ssh/id_rsa

      [rsyslog]
      type = sftp
      host = bergmannnas.fritz.box
      user = borg
      key_file = /root/.ssh/id_rsa

      [paperless]
      type = sftp
      host = bergmannnas.fritz.box
      user = borg
      key_file = /root/.ssh/id_rsa
    '';
    mode = "755";
  };
}
