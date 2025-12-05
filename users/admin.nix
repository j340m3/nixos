{ config, pkgs, lib }:
{
  users.users.admin = {
    isNormalUser = true;
    description  = "System administrator";
    extraGroups  = [ "wheel" ];   # wheel = sudo
    initialHashedPassword = "$y$j9T$PIbbCIIeb9txERacY8WTn.$hffHW7t4bx1g4tWZ2nf6r6IEmT1QEfkkn9zMbD/tFf3";           # change with `passwd admin` later
    openssh.authorizedKeys.keys = [
      # (optional) paste your SSH public key here
      # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."
    ];
  };
  users.groups.admin = {};
  users.mutableUsers = false;

  security = {
    polkit.enable = true;
    # Disable sudo
    sudo.enable = false;
    wrappers = {
      su.setuid = lib.mkForce false;
      sudo.setuid = lib.mkForce false;
      sudoedit.setuid = lib.mkForce false;
      sg.setuid = lib.mkForce false;
      fusermount.setuid = lib.mkForce false;
      fusermount3.setuid = lib.mkForce false;
      mount.setuid = lib.mkForce false;
      pkexec.setuid = lib.mkForce false;
      newgrp.setuid = lib.mkForce false;
      newgidmap.setuid = lib.mkForce false;
      newuidmap.setuid = lib.mkForce false;
    };
# Or hyprlock, required for swaylock to accept your password
    pam.services.swaylock = {
      text = ''
        auth include login
        account include login
        password include login
        session include login
      '';
    };
  };
}
