{
  config,
  lib,
  pkgs,
  ...
} : { 
  services.borgbackup.repos = {
    matrix = {
      path = "/var/lib/borgbackup/matrix";
      authorizedKeysAppendOnly = [];
    };
    minetest = {
      path = "/var/lib/borgbackup/minetest";
      authorizedKeysAppendOnly = [];
    };
    nextcloud = {
      path = "/var/lib/borgbackup/nextcloud";
      authorizedKeysAppendOnly = [];
    };
    vaultwarden = {
      path = "/var/lib/borgbackup/vaultwarden";
      authorizedKeysAppendOnly = [];
    };
  };
}