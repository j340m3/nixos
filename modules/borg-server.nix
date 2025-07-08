{
  config,
  lib,
  pkgs,
  ...
} : { 
  services.borgbackup.repos = {
    matrix = {
      path = "/var/lib/borgbackup/matrix";
      authorizedKeysAppendOnly = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFuaGVhBlZ1yTk4NfbQwRTkFYcL4H86wbx2NJH4oMtRx mtrx"];
    };
    minetest = {
      path = "/var/lib/borgbackup/minetest";
      authorizedKeysAppendOnly = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMHzhGXrb4GrFuRKi1bTdXcEz9J8vrGk/cn8KeDDlntI lnti"];
    };
    minecraft-bedrock = {
      path = "/var/lib/borgbackup/minecraft-bedrock";
      authorizedKeysAppendOnly = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM5Y64l29rfKiDBGrLDllN6rRzoDeMiyLCaoPN8LYpAH jessie"];
    };
    # nextcloud = {
    #   path = "/var/lib/borgbackup/nextcloud";
    #   authorizedKeysAppendOnly = [];
    # };
    # vaultwarden = {
    #   path = "/var/lib/borgbackup/vaultwarden";
    #   authorizedKeysAppendOnly = [];
    # };
  };
  
}