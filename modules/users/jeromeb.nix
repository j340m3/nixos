# Primary user account (Jerome): account, shell, yubikey agent, the filen
# rclone mount and its sops-injected rclone config.
{ inputs, ... }: {
  flake.modules.nixos.jeromeb = {
    pkgs,
    config,
    ...
  }: {
    users.groups.users.gid = 100;
    users.users.jeromeb = {
      uid = 1001;
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

    sops.secrets."filen/jeromeb.conf" = {
      format = "ini";
      sopsFile = ../../secrets/users/jeromeb/rclone.ini;
      owner = "jeromeb";
      group = "users";
      key = "";
    };

    fileSystems."/mnt/filen/users/jeromeb" = inputs.self.lib.rcloneMount {
      device = "filen:users/jerome";
      configPath = config.sops.secrets."filen/jeromeb.conf".path;
      uid = config.users.users.jeromeb.uid;
      gid = toString config.users.groups.users.gid;
      options = [
        "noauto"
        "x-systemd.automount"
        "log-level=INFO"
        "log-file=/var/log/rclone/filen/jeromeb.log"
      ];
    };
  };
}
